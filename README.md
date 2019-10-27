# wsldme

wsldme(WSL Docker-machine Expansion) version 0.1.6  
一个为 WSL 编写的 Docker-machine 扩展，目的是让 WSL 也能快速、方便的使用及管理 Docker Engine。

## 要求

### 系统及 WSL 要求

1. Windows 10 1803 及以上（其余版本未经测试）
2. WSL Debian（其余发行版本未经测试）

### 软件环境及工具

1. [VirtualBox 6.x](https://www.virtualbox.org/wiki/Downloads)
2. [boot2docker](https://github.com/boot2docker/boot2docker/releases)
3. [Docker-machine](https://github.com/docker/machine/releases)
4. [Docker-cli](https://github.com/docker/cli)（可选）

#### 说明

- VirtualBox 下载及安装在 Windows 主机上；  
- Docker-machine下载 Linux 版本并安装在 WSL 上；  
- boot2docker 下载后将 ISO 文件按个人习惯保存在 Windows 上面适合的目录；
- Docker-cli，即 Docker 的命令行客户端，利用他可以使得 Docker 的操作更加方便，相关安装方式请参阅[Docker 的安装文档](https://docs.docker.com/install/)。  
需要注意，官方文档指导安装的是一个完整的 Docker（包括服务端、客户端等）。因为 Docker 的服务端目前无法在 WSL 上面正常工作，所以，WSL只需要安装 Docker 的命令行客户端即 Docker-cli 便可。

``` bash
$ sudo apt-get install docker-ce-cli
```

Docker-machine 安装好后，确保能执行如下命令：

``` bash
$ docker-machine -v
```

## wsldme 安装及配置

### 下载

``` bash
$ wget https://github.com/unihon/wsldme/releases/download/v0.1.6/wsldme.sh -O /tmp/wsldme.sh
```

### 配置

``` bash
$ vim /tmp/wsldme.sh
```

``` bash
#* Windows 上 VBoxManage 的路径（VBoxManage 是 VirtualBox 配套的命令行管理工具）
vbm_path="C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

#* Windows 上 boot2docker.iso 的路径
b2d_iso_path="C:\Users\qhlgd\Documents\ISO\boot2docker.iso"

#* VritualBox 的虚拟机文件保存路径（可自定义）
vbf_path="C:\Users\qhlgd\Documents\VirtualBox Files"
```

wsldme 的 DHCP 配置信息，默认的网段为 `192.168.22.00/24`，如 VirtualBox 现有的 DHCP Server 与之相同，则会引起冲突，请修改两者其一的网段。

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

## wsldme 使用方法

Usage: wsldme [OPTIONS] COMMAND

**请用 wslme 命令代替部分 docker-machine 命令**

| docker-machine | wsldme | 说明 |
| - | - | - |
| ~~docker-machine create --driver=virtualbox d-test~~ | wsldme create [-c] d-test | 创建 Docker Engine，`-c` 国内镜像加速 |
| ~~docker-machine rm d-test~~ | wsldme rm d-test | 删除 Docker Engine |
| ~~docker-machine start d-test~~ | wsldme start d-test | 启动 Docker Engine |
| ~~docker-machine stop d-test~~ | wsldme stop d-test | 停止 Docker Engine |
| ~~docker-machine restart d-test~~ | wsldme restart d-test | 重启 Docker Engine |

## 效果

![show](https://raw.githubusercontent.com/unihon/wsldme/master/public/show.png)


## 其他问题

如果 Docker Engine 创建或者是启动失败，出现以下信息：

```
VBoxManage.exe: error: Failed to open/create the internal network 'HostInterfaceNetworking-VirtualBox Host-Only Ethernet Adapter' (VERR_INTNET_FLT_IF_NOT_FOUND).
VBoxManage.exe: error: Failed to attach the network LUN (VERR_INTNET_FLT_IF_NOT_FOUND)
VBoxManage.exe: error: Details: code E_FAIL (0x80004005), component ConsoleWrap, interface IConsole
Start error. You can restart the machine if you need it.
```

可以尝试重启相应的网卡。

```
run: ncpa.cpl
```
