#!/bin/bash

# 简化版 - 直接在远程Docker中下载Ubuntu软件包(使用清华源)

REMOTE_HOST="192.168.31.240"
REMOTE_USER="root"

echo "连接到 ${REMOTE_HOST} 并在Docker中使用清华源下载软件包..."

ssh ${REMOTE_USER}@${REMOTE_HOST} 'bash -s' << 'SCRIPT'
#!/bin/bash
set -e

CONTAINER_NAME="pkg-downloader"
DOWNLOAD_DIR="/tmp/offline-packages"

# 清理旧容器
docker stop ${CONTAINER_NAME} 2>/dev/null || true
docker rm ${CONTAINER_NAME} 2>/dev/null || true

# 创建本地目录
mkdir -p ${DOWNLOAD_DIR}

# 启动容器
echo "启动Ubuntu容器..."
docker run -d --name ${CONTAINER_NAME} -v ${DOWNLOAD_DIR}:/download ubuntu:latest tail -f /dev/null
sleep 2

# 在容器中执行下载
docker exec ${CONTAINER_NAME} bash -c '
    set -e
    
    # 先安装基础工具
    echo "安装基础工具..."
    apt-get update && \
    apt-get install -y lsb-release gnupg wget && \
    
    # 获取Ubuntu版本
    UBUNTU_VERSION=$(lsb_release -cs)
    echo "Ubuntu版本: $UBUNTU_VERSION"
    
    # 备份原配置
    [ -f /etc/apt/sources.list ] && cp /etc/apt/sources.list /etc/apt/sources.list.bak
    [ -f /etc/apt/sources.list.d/ubuntu.sources ] && cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak
    
    # 替换为清华源
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
        # DEB822格式
        cat > /etc/apt/sources.list.d/ubuntu.sources << EOF
Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/ubuntu
Suites: ${UBUNTU_VERSION} ${UBUNTU_VERSION}-updates ${UBUNTU_VERSION}-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/ubuntu
Suites: ${UBUNTU_VERSION}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
    else
        # 传统格式
        cat > /etc/apt/sources.list << EOF
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION} main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-security main restricted universe multiverse
EOF
    fi
    
    echo "已替换为清华大学镜像源"
    
    # 更新并安装工具
    apt-get update && \
    apt-get install -y apt-rdepends && \
    
    # 添加PostgreSQL仓库(优先使用清华源)
    PGDG_CODENAME=$(lsb_release -cs) && \
    if wget --spider -q "https://mirrors.tuna.tsinghua.edu.cn/postgresql/repos/apt/dists/${PGDG_CODENAME}-pgdg/"; then
        echo "使用清华PostgreSQL源"
        sh -c "echo \"deb https://mirrors.tuna.tsinghua.edu.cn/postgresql/repos/apt ${PGDG_CODENAME}-pgdg main\" > /etc/apt/sources.list.d/pgdg.list"
        wget --quiet -O - https://mirrors.tuna.tsinghua.edu.cn/postgresql/repos/apt/ACCC4CF8.asc | apt-key add -
    else
        echo "使用官方PostgreSQL源"
        sh -c "echo \"deb http://apt.postgresql.org/pub/repos/apt ${PGDG_CODENAME}-pgdg main\" > /etc/apt/sources.list.d/pgdg.list"
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    fi && \
    
    apt-get update && \
    
    # 下载软件包
    cd /download && \
    for pkg in nginx postgresql-12 openjdk-11-jdk; do
        echo "下载 $pkg 及其依赖..."
        deps=$(apt-rdepends $pkg 2>/dev/null | grep -v "^ " | sort -u)
        for dep in $deps; do
            apt-get download $dep 2>/dev/null || true
        done
    done && \
    
    echo "下载完成! 共 $(ls -1 *.deb 2>/dev/null | wc -l) 个包"
'

echo "下载完成! 文件位于: ${DOWNLOAD_DIR}"
ls -lh ${DOWNLOAD_DIR}/*.deb 2>/dev/null | tail -5
echo "总计: $(ls -1 ${DOWNLOAD_DIR}/*.deb 2>/dev/null | wc -l) 个deb包"
SCRIPT

echo "完成!"
