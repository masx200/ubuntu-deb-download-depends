# Ubuntu 离线软件包下载工具

这个工具可以帮助你在远程服务器的Docker容器中下载Ubuntu软件包及其所有依赖，用于离线部署。

**✨ 新特性**: 已集成**清华大学镜像源**,大幅提升下载速度!

## 功能特性

- ✅ SSH连接到远程服务器
- ✅ 在Docker容器中运行Ubuntu
- ✅ **自动配置清华大学镜像源**
- ✅ 自动安装apt-rdepends工具分析依赖
- ✅ 递归下载所有依赖包
- ✅ 支持下载: nginx, postgresql-12, openjdk-11-jdk

## 前置要求

1. **本地机器**:
   - 已安装SSH客户端
   - 能够SSH连接到远程服务器

2. **远程服务器 (192.168.31.240)**:
   - 已安装Docker
   - SSH服务正在运行
   - 有root访问权限

## 使用方法

### 方法一: 使用完整版脚本 (推荐)

```bash
# 给脚本添加执行权限
chmod +x download-packages.sh

# 运行脚本
./download-packages.sh
```

### 方法二: 使用简化版脚本

```bash
# 给脚本添加执行权限
chmod +x download-simple.sh

# 运行脚本
./download-simple.sh
```

## 脚本执行流程

1. SSH连接到 `root@192.168.31.240`
2. 在远程服务器上启动Ubuntu Docker容器
3. 在容器内安装必要工具 (apt-rdepends, wget等)
4. 添加PostgreSQL官方仓库
5. 使用apt-rdepends分析依赖树
6. 下载所有软件包及其依赖到 `/tmp/offline-packages`
7. 显示下载结果统计

## 下载后的操作

### 1. 查看下载的文件

```bash
ssh root@192.168.31.240 'ls -lh /tmp/offline-packages/*.deb | head -20'
ssh root@192.168.31.240 'du -sh /tmp/offline-packages'
```

### 2. 复制到本地机器

```bash
scp -r root@192.168.31.240:/tmp/offline-packages ./ubuntu-offline-packages
```

### 3. 传输到目标离线机器

使用U盘或其他方式将下载的deb包复制到目标机器

### 4. 在离线机器上安装

```bash
# 进入deb包目录
cd /path/to/offline-packages

# 安装所有包
sudo dpkg -i *.deb

# 如果遇到依赖问题，尝试修复
sudo apt-get install -f -y
```

## 自定义修改

### 修改要下载的软件包

编辑脚本中的PACKAGES变量:

```bash
# 在脚本中找到这一行并修改
PACKAGES="nginx postgresql-12 openjdk-11-jdk"

# 例如添加其他软件包:
PACKAGES="nginx postgresql-12 openjdk-11-jdk redis-server mysql-server"
```

### 修改远程服务器地址

编辑脚本顶部的REMOTE_HOST变量:

```bash
REMOTE_HOST="你的服务器IP"
```

### 修改下载目录

编辑脚本中的DOWNLOAD_DIR变量:

```bash
DOWNLOAD_DIR="/your/custom/path"
```

## 常见问题

### Q: 下载失败怎么办?
A: 检查以下几点:
- 确保远程服务器可以访问互联网
- 确认Docker正常运行: `docker ps`
- 检查SSH连接是否正常
- 查看容器日志: `docker logs pkg-downloader`

### Q: 如何重新下载?
A: 直接再次运行脚本即可，脚本会自动清理旧的容器和数据

### Q: 下载的文件很大怎么办?
A: 这是正常的，完整依赖可能需要几百MB到1GB空间。确保有足够的磁盘空间。

### Q: 如何在另一台机器上离线安装?
A: 将所有.deb文件复制到目标机器，然后执行:
```bash
sudo dpkg -i *.deb
```

### Q: 依赖冲突怎么办?
A: 尝试以下方法:
```bash
# 先安装核心包
sudo dpkg -i package-name.deb

# 让系统自动解决依赖
sudo apt-get install -f -y
```

## 技术说明

### apt-rdepends vs apt download

- **apt-rdepends**: 递归分析软件包的完整依赖树
- **apt-get download**: 下载单个软件包(不自动下载依赖)

两者结合使用可以确保下载所有必要的依赖包。

### 为什么使用Docker容器?

1. **环境隔离**: 不影响远程服务器的现有环境
2. **干净环境**: 确保依赖分析的准确性
3. **可重复**: 可以随时重建容器重新下载
4. **安全**: 所有操作在容器内进行

### 系统兼容性

确保下载环境和目标环境的以下信息一致:
- Ubuntu版本 (如 20.04, 22.04)
- 系统架构 (amd64, arm64)

可以使用以下命令检查:
```bash
lsb_release -a    # 查看Ubuntu版本
dpkg --print-architecture  # 查看系统架构
```

## 替代方案: 使用apt-offline

如果上述方法遇到问题，可以使用更专业的apt-offline工具:

### 在离线机器上:
```bash
apt-offline set offline.sig --install-packages nginx postgresql-12 openjdk-11-jdk
```

### 在联网机器上:
```bash
apt-offline get offline.sig --bundle offline.zip
```

### 回到离线机器:
```bash
apt-offline install offline.zip
```

## 许可证

本脚本免费提供，仅供学习和使用。

## 贡献

如有问题或建议，欢迎提出issue。
