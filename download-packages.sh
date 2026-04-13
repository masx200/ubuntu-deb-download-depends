#!/bin/bash

# Ubuntu离线软件包下载脚本
# 用于在Docker容器中下载nginx、postgresql-12、openjdk-11-jdk及其所有依赖
# 使用清华大学镜像源加速下载

set -e

echo "========================================="
echo "Ubuntu离线软件包下载工具 (清华源版)"
echo "========================================="

# 配置变量
REMOTE_HOST="192.168.31.240"
REMOTE_USER="root"
CONTAINER_NAME="ubuntu-package-downloader"
DOWNLOAD_DIR="/tmp/ubuntu-offline-packages"

# 要下载的软件包列表
PACKAGES="nginx postgresql-12 openjdk-11-jdk"

echo ""
echo "步骤1: SSH连接到远程服务器并启动Docker容器..."
ssh ${REMOTE_USER}@${REMOTE_HOST} << 'EOF'
    # 检查Docker是否运行
    if ! docker ps > /dev/null 2>&1; then
        echo "错误: Docker未运行或未安装"
        exit 1
    fi
    
    # 停止并删除已存在的容器
    docker stop ${CONTAINER_NAME} 2>/dev/null || true
    docker rm ${CONTAINER_NAME} 2>/dev/null || true
    
    # 创建下载目录
    mkdir -p ${DOWNLOAD_DIR}
    
    # 启动Ubuntu容器,挂载下载目录
    echo "启动Ubuntu容器..."
    docker run -d \
        --name ${CONTAINER_NAME} \
        -v ${DOWNLOAD_DIR}:/download \
        ubuntu:latest \
        tail -f /dev/null
    
    echo "容器启动成功!"
EOF

echo ""
echo "步骤2: 在容器中配置清华源并下载软件包..."
ssh ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
    # 进入容器执行命令
    docker exec ${CONTAINER_NAME} bash -c '
        set -e
        
        echo "========================================="
        echo "步骤1: 初始化环境并安装必要工具"
        echo "========================================="
        
        # 先更新包列表并安装基础工具
        apt-get update -y
        apt-get install -y lsb-release gnupg wget
        
        echo "✓ 基础工具安装完成"
        
        echo ""
        echo "========================================="
        echo "步骤2: 检测Ubuntu版本并配置清华源"
        echo "========================================="
        
        # 获取Ubuntu版本信息
        UBUNTU_VERSION=$(lsb_release -cs)
        echo "检测到Ubuntu代号: $UBUNTU_VERSION"
        
        # 备份原始源配置
        if [ -f /etc/apt/sources.list ]; then
            cp /etc/apt/sources.list /etc/apt/sources.list.bak
            echo "已备份 /etc/apt/sources.list"
        fi
        
        if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
            cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak
            echo "已备份 /etc/apt/sources.list.d/ubuntu.sources"
        fi
        
        echo ""
        echo "正在替换为清华大学镜像源..."
        
        # 检测使用哪种格式的源配置
        if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
            # DEB822格式 (Ubuntu 24.04+)
            cat > /etc/apt/sources.list.d/ubuntu.sources << SRCEOF
Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/ubuntu
Suites: ${UBUNTU_VERSION} ${UBUNTU_VERSION}-updates ${UBUNTU_VERSION}-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb-src
URIs: https://mirrors.tuna.tsinghua.edu.cn/ubuntu
Suites: ${UBUNTU_VERSION} ${UBUNTU_VERSION}-updates ${UBUNTU_VERSION}-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/ubuntu
Suites: ${UBUNTU_VERSION}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb-src
URIs: https://mirrors.tuna.tsinghua.edu.cn/ubuntu
Suites: ${UBUNTU_VERSION}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
SRCEOF
            echo "✓ DEB822格式源配置已更新"
        else
            # 传统格式 (Ubuntu 24.04之前)
            cat > /etc/apt/sources.list << SRCEOF
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION} main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-security main restricted universe multiverse
SRCEOF
            echo "✓ 传统格式源配置已更新"
        fi
        
        echo ""
        echo "========================================="
        echo "步骤3: 使用清华源更新软件包列表"
        echo "========================================="
        apt-get update -y
        
        echo ""
        echo "========================================="
        echo "步骤4: 安装apt-rdepends工具"
        echo "========================================="
        apt-get install -y apt-rdepends
        
        echo ""
        echo "========================================="
        echo "步骤5: 添加PostgreSQL仓库(优先使用清华源)"
        echo "========================================="
        PGDG_CODENAME=$(lsb_release -cs)
        
        # 尝试使用清华源的PostgreSQL仓库
        if wget --spider -q "https://mirrors.tuna.tsinghua.edu.cn/postgresql/repos/apt/dists/${PGDG_CODENAME}-pgdg/"; then
            echo "检测到清华大学PostgreSQL镜像,使用清华源..."
            sh -c "echo \"deb https://mirrors.tuna.tsinghua.edu.cn/postgresql/repos/apt ${PGDG_CODENAME}-pgdg main\" > /etc/apt/sources.list.d/pgdg.list"
            wget --quiet -O - https://mirrors.tuna.tsinghua.edu.cn/postgresql/repos/apt/ACCC4CF8.asc | apt-key add -
        else
            echo "使用PostgreSQL官方源..."
            sh -c "echo \"deb http://apt.postgresql.org/pub/repos/apt ${PGDG_CODENAME}-pgdg main\" > /etc/apt/sources.list.d/pgdg.list"
            wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
        fi
        
        apt-get update -y
        
        echo ""
        echo "========================================="
        echo "步骤6: 开始下载软件包及其依赖到/download目录"
        echo "========================================="
        cd /download
        
        # 定义要下载的软件包
        PACKAGES="nginx postgresql-12 openjdk-11-jdk"
        
        TOTAL_SUCCESS=0
        TOTAL_FAILED=0
        
        for pkg in $PACKAGES; do
            echo ""
            echo "========================================="
            echo "正在处理: $pkg"
            echo "========================================="
            
            # 获取所有递归依赖(去重)
            deps=$(apt-rdepends $pkg 2>/dev/null | grep -v "^ " | sort -u)
            dep_count=$(echo "$deps" | wc -l)
            
            echo "找到 $dep_count 个依赖包"
            
            # 下载每个依赖包
            success=0
            failed=0
            current=0
            
            for dep in $deps; do
                current=$((current + 1))
                if apt-get download $dep 2>/dev/null; then
                    success=$((success + 1))
                    TOTAL_SUCCESS=$((TOTAL_SUCCESS + 1))
                    echo "  [$current/$dep_count] ✓ 已下载: $dep"
                else
                    failed=$((failed + 1))
                    TOTAL_FAILED=$((TOTAL_FAILED + 1))
                    echo "  [$current/$dep_count] ✗ 无法下载: $dep"
                fi
            done
            
            echo ""
            echo "$pkg 完成: 成功$success个, 失败$failed个"
        done
        
        echo ""
        echo "========================================="
        echo "下载统计"
        echo "========================================="
        echo "总成功: $TOTAL_SUCCESS"
        echo "总失败: $TOTAL_FAILED"
        echo ""
        
        DEB_COUNT=$(ls -1 *.deb 2>/dev/null | wc -l)
        if [ "$DEB_COUNT" -gt 0 ]; then
            echo "下载的deb包数量: $DEB_COUNT"
            echo "总大小: $(du -sh /download | cut -f1)"
            echo ""
            echo "文件列表 (前20个):"
            ls -lh *.deb 2>/dev/null | head -20
            if [ "$DEB_COUNT" -gt 20 ]; then
                echo "... 还有 $((DEB_COUNT - 20)) 个文件"
            fi
        else
            echo "警告: 没有下载到任何deb包!"
        fi
        
        echo ""
        echo "========================================="
        echo "所有下载完成!"
        echo "========================================="
        echo "保存位置: /download (映射到宿主机的 ${DOWNLOAD_DIR})"
    '
ENDSSH

echo ""
echo "步骤3: 验证下载结果..."
ssh ${REMOTE_USER}@${REMOTE_HOST} << 'EOF'
    echo "检查下载目录..."
    if [ -d "${DOWNLOAD_DIR}" ]; then
        echo "下载目录内容:"
        ls -lh ${DOWNLOAD_DIR}/*.deb 2>/dev/null | head -10
        echo ""
        echo "总计: \$(ls -1 ${DOWNLOAD_DIR}/*.deb 2>/dev/null | wc -l) 个deb包"
        echo "总大小: \$(du -sh ${DOWNLOAD_DIR} | cut -f1)"
    else
        echo "错误: 下载目录不存在"
    fi
EOF

echo ""
echo "========================================="
echo "操作完成!"
echo "========================================="
echo "所有deb包已下载到远程服务器: ${DOWNLOAD_DIR}"
echo ""
echo "后续步骤:"
echo "1. 在远程服务器上查看: ssh ${REMOTE_USER}@${REMOTE_HOST} 'ls -lh ${DOWNLOAD_DIR}'"
echo "2. 复制到本地: scp -r ${REMOTE_USER}@${REMOTE_HOST}:${DOWNLOAD_DIR} ./ubuntu-offline-packages"
echo "3. 离线安装时,在目标机器执行: sudo dpkg -i *.deb"
echo "========================================="
