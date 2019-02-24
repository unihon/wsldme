# wsldme

wsldme(WSL Docker-machine Expansion) version 0.1.0  
一个为WSL编写的Docker-machine扩展，目的是让WSL也能快速、方便的使用及管理Docker。

## 要求

### 系统及WSL要求

1. Windows 10 1803及以上（其余版本未经测试）
2. WSL Debian（其余发行版本未经测试）

### 软件环境及工具

1. [VirtualBox 6.x](https://www.virtualbox.org/wiki/Downloads)
2. [boot2docker](https://github.com/boot2docker/boot2docker/releases)
3. [Docker-machine](https://github.com/docker/machine/releases)

#### 说明

VirtualBox下载及安装在Windows主机上；  
Docker-machine下载Linux版本并安装在WSL上；  
boot2docker下载后将ISO文件按个人习惯保存在Windows上面适合的目录。

Docker-machine安装好后，确保能执行如下命令：

``` bash
$ docker-machine -v
```

## wsldme安装及配置

### 下载

``` bash
$ wget https://github.com/unihon/wsldme/releases/download/v0.1.0/wsldme.sh -O /tmp/wsldme.sh
```

### 配置

``` bash
$ vim /tmp/wsldme.sh
```

``` bash
#* Windows上VBoxManage的路径（VBoxManage是VirtualBox配套的命令行管理工具）
vbm_path="C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

#* Windows上boot2docker.iso的路径
b2d_iso_path="C:\Users\qhlgd\Documents\ISO\boot2docker.iso"

#* VritualBox的虚拟机文件保存路径（可自定义）
vbf_path="C:\Users\qhlgd\Documents\VirtualBox Files"
```

wsldme的DHCP配置信息，默认的网段为`192.168.22.00/24`，如VirtualBox现有的DHCP Server与之相同，则会引起冲突，请修改两者其一的网段。

``` bash
dhcp_ip="192.168.22.22"
dhcp_netmask="255.255.255.0"
dhcp_lowerip="192.168.22.100"
dhcp_upperip="192.168.22.254"
```

配置好必要项后安装

``` bash
$ chmod 755 /tmp/wsldme.sh && mv -i /tmp/wsldme.sh /usr/local/bin/wsldme
$ wsldme version
```

## wsldme使用方法

Usage: wsldme [OPTIONS] COMMAND

**请用wslme命令代替部分docker-machine命令**

| docker-machine | wsldme | 说明 |
| - | - | - |
| ~~docker-machine create --driver=virtualbox d-test~~ | wsldme create  d-test | 创建Docker Engine |
| ~~docker-machine rm d-test~~ | wsldme rm d-test | 删除Docker Engine |
| ~~docker-machine start d-test~~ | wsldme start d-test | 启动Docker Engine |
| ~~docker-machine stop d-test~~ | wsldme stop d-test | 停止Docker Engine |
| ~~docker-machine restart d-test~~ | wsldme restart d-test | 重启Docker Engine |
