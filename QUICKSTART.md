# 快速开始指南

## 🚀 5分钟快速使用

### 前置条件
- ✅ 确保可以SSH连接到 `192.168.31.240`
- ✅ 远程服务器已安装Docker
- ✅ 远程服务器可以访问互联网

### ✨ 特性说明

**本脚本已集成清华大学镜像源**,将自动:
- 检测Ubuntu版本并配置对应的清华源
- 优先使用清华PostgreSQL镜像
- 大幅提升下载速度(国内用户)

### Windows用户 (推荐)

#### 方法1: 双击运行批处理文件
1. 双击 `download-packages.bat`
2. 按提示操作
3. 等待下载完成

#### 方法2: 使用PowerShell
```powershell
# 以管理员身份运行PowerShell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\download-packages.ps1
```

### Linux/Mac用户

```bash
# 1. 添加执行权限
chmod +x download-packages.sh

# 2. 运行脚本
./download-packages.sh
```

---

## 📦 下载的软件包

脚本会自动下载以下软件及其**所有依赖**:
- ✅ nginx (Web服务器)
- ✅ postgresql-12 (PostgreSQL数据库)
- ✅ openjdk-11-jdk (Java开发工具包)

预计下载: **300-500个deb包**, 总大小约 **500MB-1GB**

---

## 📥 获取下载的文件

下载完成后,在远程服务器上查看:

```bash
ssh root@192.168.31.240 "ls -lh /tmp/offline-packages/*.deb | head -10"
ssh root@192.168.31.240 "du -sh /tmp/offline-packages"
```

复制到本地:

```bash
scp -r root@192.168.31.240:/tmp/offline-packages ./ubuntu-offline-packages
```

---

## 💿 离线安装

将下载的deb包复制到目标离线机器后:

```bash
cd ubuntu-offline-packages
sudo dpkg -i *.deb
```

如果遇到依赖问题:

```bash
sudo apt-get install -f -y
```

---

## 🔧 自定义配置

### 修改要下载的软件

编辑 `download-remote.sh`,找到这一行并修改:

```bash
PACKAGES="nginx postgresql-12 openjdk-11-jdk"
```

例如添加Redis:

```bash
PACKAGES="nginx postgresql-12 openjdk-11-jdk redis-server"
```

### 修改远程服务器地址

在所有脚本文件中替换IP地址:
- `download-packages.sh`
- `download-simple.sh`
- `download-packages.bat`
- `download-packages.ps1`

将 `192.168.31.240` 改为你的服务器IP

---

## ❓ 故障排除

### 问题1: SSH连接失败

**症状**: 无法连接到远程服务器

**解决**:
```bash
# 测试连接
ping 192.168.31.240

# 检查SSH服务
ssh root@192.168.31.240 "echo test"
```

### 问题2: Docker未运行

**症状**: "Docker未安装或未运行"

**解决**:
```bash
# 启动Docker
sudo systemctl start docker
sudo systemctl enable docker

# 验证
docker ps
```

### 问题3: 下载速度慢

**原因**: 需要从Ubuntu官方仓库下载大量文件

**解决**: 
- 耐心等待,可能需要10-30分钟
- 确保网络连接稳定

### 问题4: 某些包下载失败

**症状**: 显示 "无法下载: xxx"

**解决**:
- 这是正常的,某些虚拟包或元数据包不需要下载
- 只要核心包下载成功即可
- 检查最终的deb包数量是否合理(应该>100个)

### 问题5: 容器启动失败

**解决**:
```bash
# 手动清理
ssh root@192.168.31.240 "docker stop pkg-downloader && docker rm pkg-downloader"

# 重新运行脚本
```

---

## 📊 预期输出示例

```
=========================================
步骤5: 开始下载软件包
=========================================

-----------------------------------------
正在处理: nginx
-----------------------------------------
找到 45 个依赖包
  [1/45] ✓ 已下载: nginx-core
  [2/45] ✓ 已下载: libnginx-mod-http
  ...

下载统计
=========================================
总成功: 387
总失败: 2

下载的deb包数量: 387
总大小: 756M
```

---

## 🎯 验证安装

在离线机器上安装后,验证软件:

```bash
# 验证Nginx
nginx -v

# 验证PostgreSQL
psql --version

# 验证Java
java -version
javac -version
```

---

## 📞 需要帮助?

如果遇到问题:
1. 查看完整的README.md文档
2. 检查脚本输出的错误信息
3. 确认系统版本兼容性 (Ubuntu 20.04/22.04)

---

## ⚡ 常用命令速查

```bash
# 查看远程文件
ssh root@192.168.31.240 "ls -lh /tmp/offline-packages/"

# 复制单个文件
scp root@192.168.31.240:/tmp/offline-packages/nginx*.deb .

# 压缩后传输
ssh root@192.168.31.240 "cd /tmp && tar czf offline-pkgs.tar.gz offline-packages/"
scp root@192.168.31.240:/tmp/offline-pkgs.tar.gz .

# 批量安装
sudo dpkg -i *.deb

# 检查安装的包
dpkg -l | grep nginx
dpkg -l | grep postgresql
dpkg -l | grep openjdk
```
