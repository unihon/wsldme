#!/usr/bin/env bash
# wsldme - wsl docker-machine extension
# <https://github.com/unihon/wsldme>
# Copyright (c) 2019 Hon Lee

wsldme_version="0.1.5"
#===============================================
# configure

#* VBoxManage path
vbm_path="C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
#* boot2docker.iso path
b2d_iso_path="C:\Users\qhlgd\Documents\ISO\boot2docker.iso"
#* vritualbox file path
vbf_path="C:\Users\qhlgd\Documents\VirtualBox Files"

#-----------------------------------------------

# virutal host memory,memory is at least 1023M and cannot be more than half of total memory
os_memory="1024"
# vhd format VDI|VMDK|VHD
vhd_format="VDI"
# vhd size M,size is at least 1024M.
vhd_size="8192"

# dhcp options
dhcp_ip="192.168.22.22"
dhcp_netmask="255.255.255.0"
dhcp_lowerip="192.168.22.100"
dhcp_upperip="192.168.22.254"

# User-friendly settings options
# user_friendly_eo=true
wsldme_data_path="/var/local/wsldme"
#===============================================

hostname=""
vh_if=""
vh_if_field="/VirtualBox/GuestInfo/Net/1/V4/IP"

VBM=$(echo "$vbm_path"|sed -e 's/\\/\//g' -e 's/\ /\\ /g' -e 's/^\(.\):\(.*\)$/\/mnt\/\l\1\2/g')
shopt -s expand_aliases
alias VBM=$VBM

#-----------------------------------------------

showHelp(){
	printf "%s\n" "Usage: wsldme [OPTIONS] COMMAND"
	printf "%s\n" "WSL Docker-machine Expansion"
	printf "%s\n" "Version: $wsldme_version"
	printf "%s\n\n" "Author: Hon Lee - <https://github.com/unihon/wsldme>"
	printf "%s\n" "Commands:"
	printf "  %-20s%s\n" "create" "Create a machine. \"-c\" flag use Chinese official image acceleration"
	printf "  %-20s%s\n" "rm" "Remove a machine"
	printf "  %-20s%s\n" "start" "Start a machine"
	printf "  %-20s%s\n" "stop" "Stop a machine"
	printf "  %-20s%s\n" "restart" "Restart a machine"
	printf "  %-20s%s\n" "status" "Get the status of a machine and update the machine IP if the machine's IP changes"
	printf "  %-20s%s\n" "rmif" "Remove boot2docker network interface and dhcp server"
	printf "  %-20s%s\n" "version" "Show the wsldme version"
	printf "  %-20s%s\n\n" "help" "Shows a list of commands or help for one command"
}

loadData(){
	[ -e "$wsldme_data_path" ] || mkdir "$wsldme_data_path"
	[ -e "$wsldme_data_path"/wsldme_data ] || cat > "$wsldme_data_path"/wsldme_data << EOF
# This is wsldme data.
# If you want to use a new interface,you can clear the data.

wsldme_docker_if=""
EOF

	# load data from config file.If "wsldme_docker_if" is empty or interface do not exist,create interface
	vh_if=$(awk -F = '/^wsldme_docker_if="(.*)"/ {gsub(/(")/,"",$2);print $2}' "$wsldme_data_path"/wsldme_data)
	if [ "$vh_if" == "" ]
	then
		createIf
		[ $? == 1 ] && exit
		return
	fi

	if_state=$(VBM list hostonlyifs|awk -F ':' -v IF="$vh_if" '/^Name:/ {gsub(/\r|^[ ]/,"",$2);if($2==IF){print "yes";exit}}')
	if [ "$if_state" != "yes" ] 
	then
		createIf
		[ $? == 1 ] && exit
		return
	fi
}

dataCheck(){
	total_memory=$(head -n 1 /proc/meminfo|awk '{print int($2/2^10/2)}')
	if [ $total_memory -lt $os_memory -o $os_memory -lt 1024 ] 
	then
		echo "os memory error."
		exit
	elif [ $vhd_size -lt 1024 ]
	then
		echo "vhd size error."
		exit
	fi

	[ $vhd_format == "VDI" ] && return
	[ $vhd_format == "VHD" ] && return
	[ $vhd_format == "VMDK" ] && return
	echo "vhd format error."
	exit
}

createErrorH(){
	stopHost
	removeHost
	exit
}

checkHost(){
	if [ "$hostname" == "" ]
	then
		echo "Hostname error."
		exit
	fi

	vh_path=${vbf_path}\\${hostname}
	vhd_path=${vh_path}\\${hostname}.${vhd_format,,}

	if [ "$(VBM list vms|egrep ^\"$hostname\")" == "" ]
	then
		# Host does not exist
		return 1
	else
		# Host exists
		return 0
	fi
}

checkState(){
	checkHost 
	if [ $? -eq 1 ]
	then
		echo  "\"$hostname\" does not exist."
		exit
	fi

	if [ "$(VBM list runningvms|egrep ^\"$hostname\")" == "" ]
	then
		# Host does not run
		return 1
	else
		# Host is running
		return 0
	fi
}

createIf(){
	echo "Create an interface..."

	vh_if=$(VBM hostonlyif create|sed -r -e "s/Interface\s'(.*?)'\swas\ssuccessfully\screated/\1/g" -e "s/\r//g")

	if [ "$vh_if" == "" ]
	then
		echo "Create interface error."
		return 1
	fi

	echo "\"$vh_if\" is created."

	if [ "$(VBM list dhcpservers|egrep '^IP:.*?192\.168\.22')" != "" ]
	then
		echo "Network segment conflict of the DHCP server, please check."
		echo "By default wsldme use the \"192.168.22.00/24\" network segment."
		return 1
	fi

	VBM hostonlyif ipconfig "$vh_if" --dhcp && VBM dhcpserver add --ifname "$vh_if" --ip $dhcp_ip --netmask $dhcp_netmask --lowerip $dhcp_lowerip --upperip $dhcp_upperip --enable
	if [ $? -ne 0 ]
	then
		echo "DHCP configure error."
		exit
	fi

	sed -i "/^wsldme_docker_if/d" "$wsldme_data_path"/wsldme_data
	echo "wsldme_docker_if=\"$vh_if\"" >> "$wsldme_data_path"/wsldme_data
	return 0
}

createHost(){
	dataCheck
	checkHost 
	if [ $? -eq 0 ]
	then
		echo  "\"$hostname\" already exists."
		exit
	fi

	loadData

	b2d_iso_linux_path_str=$(echo "$b2d_iso_path"|sed -e 's/\\/\//g' -e 's/^\(.\):\(.*\)$/\/mnt\/\l\1\2/g')
	vh_linux_path_str=$(echo "$vh_path"|sed -e 's/\\/\//g' -e 's/^\(.\):\(.*\)$/\/mnt\/\l\1\2/g')

	mkdir -p "$vh_linux_path_str"
	cp "$b2d_iso_linux_path_str" "$vh_linux_path_str"


	VBM createvm --name $hostname --register || createErrorH
	VBM modifyvm $hostname --ostype linux26_64 --memory $os_memory || createErrorH

	VBM createmedium --filename "$vhd_path"  --format $vhd_format --size $vhd_size ||createErrorH 

	VBM storagectl $hostname --name SATA --add sata --hostiocache on || createErrorH

	VBM storageattach $hostname --storagectl SATA --port 0 --device 0 --type dvddrive --medium "$vh_path/boot2docker.iso" || createErrorH
	VBM storageattach $hostname --storagectl SATA --port 1 --device 0 --type hdd --medium "$vhd_path" || createErrorH

	VBM modifyvm $hostname --nic1 nat --nictype1 82540EM --cableconnected1 on || createErrorH
	VBM modifyvm $hostname --nic2 hostonly --nictype2 82540EM --nicpromisc2 deny --cableconnected2 on --hostonlyadapter2 "$vh_if" || createErrorH
}

removeHost(){
	echo "Removing \"$hostname\"..."
	rm -rf ~/.docker/machine/machines/$hostname
	VBM unregistervm --delete $hostname || exit

	vh_linux_path_str=$(echo "$vh_path"|sed -e 's/\\/\//g' -e 's/^\(.\):\(.*\)$/\/mnt\/\l\1\2/g')
	rm -rf "$vh_linux_path_str"
}

startHost(){
	checkState
	if [ $? -eq 0 ]
	then
		echo "\"$hostname\" is running. You can restart or stop the machine if you need it."
		exit
	fi

	echo "Starting \"$hostname\"..."

	start_state=`VBM startvm $hostname --type headless|egrep -o 'has been successfully started'`

	if [ "$start_state" == "" ]
	then
		echo "Start error. You can restart the machine if you need it."
		exit
	fi

	echo "\"$hostname\" start successfully!"
	getIp
	echo "Started machines may have new IP addresses. You may need to re-run the \`docker-machine env\` command."
}

stopHost(){
	checkState
	if [ $? -eq 1 ]
	then
		echo "\"$hostname\" does not run."
		return
	fi

	echo "Stoping \"$hostname\"..."

	VBM controlvm $hostname poweroff
	[ -e ~/.docker/machine/machines/${hostname}/config.json ] && sed -E -i "s/(\"IPAddress\"):\s(\".*?\")/\1: \" \"/" ~/.docker/machine/machines/${hostname}/config.json

	docker-machine env -u
}

getIp(){
	echo "Waiting for an IP..."

	for i in $(seq 60)
	do
		sleep 2
		host_ip=$(VBM guestproperty enumerate $hostname --patterns $vh_if_field|egrep -o "([0-9]{1,3}\.){3}[0-9]{1,3}")
		if [ "$host_ip" != "" ]
		then
			break
		fi
	done

	if [ "$host_ip" == "" ]
	then
		echo "Failed to get IP."
		[ -e ~/.docker/machine/machines/${hostname}/config.json ] && sed -E -i "s/(\"IPAddress\"):\s(\".*?\")/\1: \" \"/" ~/.docker/machine/machines/${hostname}/config.json
		exit
	else
		[ -e ~/.docker/machine/machines/${hostname}/config.json ] && sed -E -i "s/(\"IPAddress\"):\s(\".*?\")/\1: \"${host_ip}\"/" ~/.docker/machine/machines/${hostname}/config.json
		echo $host_ip
	fi
}

hostState(){
	checkState
	if [ $? -eq 0 ]
	then
		echo "\"$hostname\" is running."
		getIp
	else
		echo "\"$hostname\" does not run."
	fi
}

createKey(){
	[ -e ~/.ssh/known_hosts ] && ssh-keygen -f ~/.ssh/known_hosts -R $host_ip 
	if [ ! -e ~/.ssh/id_rsa ]
	then
		echo "Authentication key generation..."
		ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
		echo -e "\n\n"
	fi
}

b2dSh(){
	ssh_key=$(cat ~/.ssh/id_rsa.pub)

	echo "Make files..."
	echo -e "\033[1;43mNote\033[0m:The password is \"\033[1;32mtcuser\033[0m\"."

	ssh -Tq -o "StrictHostKeyChecking=no" docker@${host_ip} << EOF
mkdir -p /var/lib/boot2docker/.ssh
echo "$ssh_key" > /var/lib/boot2docker/.ssh/authorized_keys
sudo cp -f /var/lib/boot2docker/.ssh/authorized_keys /home/docker/.ssh
tar -cvf /var/lib/boot2docker/userdata.tar /var/lib/boot2docker/.ssh --remove-files
echo 'DOCKER_HOST="-H tcp://0.0.0.0:2376"' > /var/lib/boot2docker/profile

[ "$mirrors_flag" == "-c" ] && sudo sh -c "echo '{\"registry-mirrors\":[\"https://registry.docker-cn.com\"]}' > /etc/docker/daemon.json"

sudo /etc/init.d/docker restart

for i in \`seq 30\`
do 
	[ "\`ss -tnl|awk '{print $4}'|egrep -o '2376'\`" != "" ] && break
	echo "Waiting..."
	sleep 1
done
exit
EOF

echo "b2d is processed."
}

dmCreate(){
	docker-machine create --driver generic --generic-ssh-user=docker --generic-ip-address=$host_ip --generic-ssh-key ~/.ssh/id_rsa $hostname
}

initHost(){
	createHost
	startHost
	createKey
	b2dSh
	dmCreate
	cat << EOF

+-----------------------------------------------+
|                                               |
|      Docker engine created successfully!      |
|                                               |
+-----------------------------------------------+

┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
 ssh docker@$host_ip                           
┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
 eval \$(docker-machine env $hostname)         
┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄

EOF
}

# delete the interface and dhcp server
rmIfAndServer(){
	if [ -e "$wsldme_data_path"/wsldme_data ]
	then
		vh_if=$(awk -F = '/^wsldme_docker_if="(.*)"/ {gsub(/(")/,"",$2);print $2}' "$wsldme_data_path"/wsldme_data)
		if [ "$vh_if" == "" ]
		then
			echo "Do not exist interface."
			exit
		fi
	else
		echo "Do not exist interface."
		exit
	fi

	if_state=$(VBM list hostonlyifs|awk -F ':' -v IF="$vh_if" '/^Name:/ {gsub(/\r|^[ ]/,"",$2);if($2==IF){print "yes";exit}}')

	if [ "$if_state" != "yes" ] 
	then
		echo "Do not exist interface."
		exit
	fi

	VBM dhcpserver remove --ifname "$vh_if" && VBM hostonlyif remove "$vh_if" && echo "Remove interface and dhcp server successfully!"
}

#-----------------------------------------------

if [ $# -eq 2 ]
then
	hostname=$(echo $2|sed '/\s/d')
elif [ $# -ge 3 ]
then
	if [ "$2" != "-c" ]
	then
		echo -e "Flag error.\n"
		showHelp
		exit
	fi
	mirrors_flag=$2
	hostname=$(echo $3|sed '/\s/d')
fi

case $1 in
	create)
		initHost
		;;
	rm)
		echo -n "Are you sure remove \"$hostname\"? (y/n):"
		read ops
		[ "$ops" == "n" ] && exit
		stopHost
		removeHost
		;;
	start)
		start_time=`date +'%s'`
		startHost
		end_time=`date +'%s'`
		echo "Startup time "$(($end_time-$start_time))s
		;;
	stop)
		stopHost
		;;
	restart)
		stopHost
		start_time=`date +'%s'`
		startHost
		end_time=`date +'%s'`
		echo "Startup time "$(($end_time-$start_time))s
		;;
	status)
		hostState
		;;
	rmif)
		echo -n "Are you sure remove interface and dhcp server? (y/n):"
		read ops
		[ "$ops" == "n" ] && exit
		rmIfAndServer
		;;
	version)
		echo "wsldme v$wsldme_version"
		;;
	*)
		showHelp;;
esac
