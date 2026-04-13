#!/bin/bash
# 此脚本在远程服务器上执行，用于在Docker容器中下载软件包

set -e

CONTAINER_NAME="pkg-downloader"
DOWNLOAD_DIR="/tmp/offline-packages"

echo "========================================="
echo "在Docker容器中下载Ubuntu软件包"
echo "========================================="

# 清理旧容器
echo "清理旧容器..."
docker stop ${CONTAINER_NAME} 2>/dev/null || true
docker rm ${CONTAINER_NAME} 2>/dev/null || true

# 创建本地目录
mkdir -p ${DOWNLOAD_DIR}

# 启动Ubuntu容器
echo "启动Ubuntu容器..."
docker run -d \
--name ${CONTAINER_NAME} \
-v ${DOWNLOAD_DIR}:/download \
ubuntu:latest \
tail -f /dev/null

sleep 2

# 验证容器运行状态
if ! docker ps | grep -q ${CONTAINER_NAME}; then
    echo "错误: 容器启动失败"
    exit 1
fi

echo "容器启动成功!"
echo ""

# 在容器中执行所有操作
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
    echo "步骤2: 检测Ubuntu版本并备份原源配置"
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
    echo "========================================="
    echo "步骤3: 替换为清华大学镜像源"
    echo "========================================="

    # 检测使用哪种格式的源配置
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
        # DEB822格式 (Ubuntu 24.04+)
        echo "检测到DEB822格式配置文件,正在替换为清华源..."

        cat > /etc/apt/sources.list.d/ubuntu.sources << EOF
Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/ubuntu
Suites: ${UBUNTU_VERSION} ${UBUNTU_VERSION}-updates ${UBUNTU_VERSION}-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
Types: deb-src
URIs: https://mirrors.tuna.tsinghua.edu.cn/ubuntu
Suites: ${UBUNTU_VERSION} ${UBUNTU_VERSION}-updates ${UBUNTU_VERSION}-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

# 以下安全更新软件源包含了官方源与镜像站配置，如有需要可自行修改注释切换
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
EOF

        echo "✓ DEB822格式源配置已更新"
    else
        # 传统格式 (Ubuntu 24.04之前)
        echo "检测到传统格式配置文件,正在替换为清华源..."

        cat > /etc/apt/sources.list << EOF
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION} main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION} main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-security main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-security main restricted universe multiverse
EOF

        echo "✓ 传统格式源配置已更新"
    fi

    echo ""
    echo "========================================="
    echo "步骤4: 使用清华源更新软件包列表"
    echo "========================================="
    apt-get update -y

    echo ""
    echo "========================================="
    echo "步骤5: 安装apt-rdepends工具"
    echo "========================================="
    apt-get install -y apt-rdepends

    echo ""
    echo "========================================="
    echo "步骤6: 添加PostgreSQL官方仓库(使用清华源)"
    echo "========================================="

    # 检查是否有PostgreSQL的清华源
    PGDG_CODENAME=$(lsb_release -cs)

    # 尝试使用清华源的PostgreSQL仓库
    if wget --spider -q "https://mirrors.tuna.tsinghua.edu.cn/postgresql/repos/apt/dists/${PGDG_CODENAME}-pgdg/"; then
        echo "检测到清华大学PostgreSQL镜像,使用清华源..."
        sh -c "echo \"deb https://mirrors.tuna.tsinghua.edu.cn/postgresql/repos/apt ${PGDG_CODENAME}-pgdg main\" > /etc/apt/sources.list.d/pgdg.list"
        wget --quiet -O - https://mirrors.tuna.tsinghua.edu.cn/postgresql/repos/apt/ACCC4CF8.asc | apt-key add -
    else
        echo "使用PostgreSQL官方源..."
        sh -c "echo \"deb https://mirrors.aliyun.com/postgresql/repos/apt ${PGDG_CODENAME}-pgdg main\" > /etc/apt/sources.list.d/pgdg.list"
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    fi

    echo ""
    echo "========================================="
    echo "步骤7: 再次更新软件包列表"
    echo "========================================="
    apt-get update -y

    echo ""
    echo "========================================="
    echo "步骤8: 开始下载软件包"
    echo "========================================="
    cd /download

    # 定义要下载的软件包
    PACKAGES="nginx postgresql-12 openjdk-11-jdk"

    TOTAL_SUCCESS=0
    TOTAL_FAILED=0

    for pkg in $PACKAGES; do
        echo ""
        echo "-----------------------------------------"
        echo "正在处理: $pkg"
        echo "-----------------------------------------"

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

    # 显示下载的文件
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
    echo "完成!"
    echo "========================================="
    echo "文件位置: /download (映射到宿主机: ${DOWNLOAD_DIR})"
'

echo ""
echo "验证下载结果..."
if [ -d "${DOWNLOAD_DIR}" ] && [ "$(ls -A ${DOWNLOAD_DIR}/*.deb 2>/dev/null)" ]; then
    DEB_COUNT=$(ls -1 ${DOWNLOAD_DIR}/*.deb 2>/dev/null | wc -l)
    TOTAL_SIZE=$(du -sh ${DOWNLOAD_DIR} | cut -f1)
    echo "✓ 下载成功!"
    echo "  文件数量: $DEB_COUNT"
    echo "  总大小: $TOTAL_SIZE"
    echo "  位置: ${DOWNLOAD_DIR}"
else
    echo "✗ 警告: 下载目录为空或不存在"
fi

echo ""
echo "提示: 可以使用以下命令复制文件:"
echo "  scp -r root@$(hostname):${DOWNLOAD_DIR} ./ubuntu-offline-packages"
        
        echo "✓ DEB822格式源配置已更新"
    else
        # 传统格式 (Ubuntu 24.04之前)
        echo "检测到传统格式配置文件,正在替换为清华源..."
        
        cat > /etc/apt/sources.list << EOF
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION} main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION} main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-security main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-security main restricted universe multiverse
EOF
        
        echo "✓ 传统格式源配置已更新"
    fi
    
    echo ""
    echo "========================================="
    echo "步骤4: 使用清华源更新软件包列表"
    echo "========================================="
    apt-get update -y
    
    echo ""
    echo "========================================="
    echo "步骤5: 安装apt-rdepends工具"
    echo "========================================="
    apt-get install -y apt-rdepends
    
    echo ""
    echo "========================================="
    echo "步骤6: 添加PostgreSQL官方仓库(使用清华源)"
    echo "========================================="
    
    # 检查是否有PostgreSQL的清华源
    PGDG_CODENAME=$(lsb_release -cs)
    
    # 尝试使用清华源的PostgreSQL仓库
    if wget --spider -q "https://mirrors.tuna.tsinghua.edu.cn/postgresql/repos/apt/dists/${PGDG_CODENAME}-pgdg/"; then
        echo "检测到清华大学PostgreSQL镜像,使用清华源..."
        sh -c "echo \"deb https://mirrors.tuna.tsinghua.edu.cn/postgresql/repos/apt ${PGDG_CODENAME}-pgdg main\" > /etc/apt/sources.list.d/pgdg.list"
        wget --quiet -O - https://mirrors.tuna.tsinghua.edu.cn/postgresql/repos/apt/ACCC4CF8.asc | apt-key add -
    else
        echo "使用PostgreSQL官方源..."
        sh -c "echo \"deb https://mirrors.aliyun.com/postgresql/repos/apt ${PGDG_CODENAME}-pgdg main\" > /etc/apt/sources.list.d/pgdg.list"
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    fi
    
    echo ""
    echo "========================================="
    echo "步骤7: 再次更新软件包列表"
    echo "========================================="
    apt-get update -y
    
    echo ""
    echo "========================================="
    echo "步骤8: 开始下载软件包"
    echo "========================================="
    cd /download
    
    # 定义要下载的软件包
    PACKAGES="nginx postgresql-12 openjdk-11-jdk"
    
    TOTAL_SUCCESS=0
    TOTAL_FAILED=0
    
    for pkg in $PACKAGES; do
        echo ""
        echo "-----------------------------------------"
        echo "正在处理: $pkg"
        echo "-----------------------------------------"
        
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
    
    # 显示下载的文件
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
    echo "完成!"
    echo "========================================="
    echo "文件位置: /download (映射到宿主机: ${DOWNLOAD_DIR})"
'

echo ""
echo "验证下载结果..."
if [ -d "${DOWNLOAD_DIR}" ] && [ "$(ls -A ${DOWNLOAD_DIR}/*.deb 2>/dev/null)" ]; then
    DEB_COUNT=$(ls -1 ${DOWNLOAD_DIR}/*.deb 2>/dev/null | wc -l)
    TOTAL_SIZE=$(du -sh ${DOWNLOAD_DIR} | cut -f1)
    echo "✓ 下载成功!"
    echo "  文件数量: $DEB_COUNT"
    echo "  总大小: $TOTAL_SIZE"
    echo "  位置: ${DOWNLOAD_DIR}"
else
    echo "✗ 警告: 下载目录为空或不存在"
fi

echo ""
echo "提示: 可以使用以下命令复制文件:"
echo "  scp -r root@$(hostname):${DOWNLOAD_DIR} ./ubuntu-offline-packages"
