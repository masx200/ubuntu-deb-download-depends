#!/bin/bash
# 此脚本在远程服务器上执行，用于在Docker容器中下载软件包
# 优化版：先收集所有依赖，一次性批量下载，加快速度

set -e

CONTAINER_NAME="pkg-downloader"
DOWNLOAD_DIR="/tmp/offline-packages"

echo "========================================="
echo "Ubuntu软件包离线下载 (优化版)"
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

# 定义要下载的软件包
PACKAGES="${1:-nginx postgresql-12 openjdk-11-jdk}"
echo "要下载的软件包: $PACKAGES"
echo ""

# 在容器中执行所有操作
docker exec ${CONTAINER_NAME} bash -c "
    set -e

    echo '========================================='
    echo '步骤1: 初始化环境并安装必要工具'
    echo '========================================='

    # 先更新包列表并安装基础工具
    apt-get update -y
    apt-get install -y lsb-release gnupg wget apt-rdepends

    echo '✓ 基础工具安装完成'

    echo ''
    echo '========================================='
    echo '步骤2: 检测Ubuntu版本并替换为清华源'
    echo '========================================='

    # 获取Ubuntu版本信息
    UBUNTU_VERSION=\$(lsb_release -cs)
    echo \"检测到Ubuntu代号: \$UBUNTU_VERSION\"

    # 检测使用哪种格式的源配置
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
        # DEB822格式 (Ubuntu 24.04+)
        echo '检测到DEB822格式配置文件,正在替换为清华源...'

        cat > /etc/apt/sources.list.d/ubuntu.sources << 'SRCEOF'
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
SRCEOF
        echo '✓ DEB822格式源配置已更新'
    else
        # 传统格式 (Ubuntu 24.04之前)
        echo '检测到传统格式配置文件,正在替换为清华源...'

        cat > /etc/apt/sources.list << 'SRCEOF'
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION} main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_VERSION}-security main restricted universe multiverse
SRCEOF
        echo '✓ 传统格式源配置已更新'
    fi

    echo ''
    echo '========================================='
    echo '步骤3: 使用清华源更新软件包列表'
    echo '========================================='
    apt-get update -y

    echo ''
    echo '========================================='
    echo '步骤4: 添加PostgreSQL仓库'
    echo '========================================='
    PGDG_CODENAME=\$(lsb_release -cs)
    
    if wget --spider -q \"https://mirrors.aliyun.com/postgresql/repos/apt/dists/\${PGDG_CODENAME}-pgdg/\"; then
        echo '使用PostgreSQL清华源...'
        sh -c \"echo 'deb https://mirrors.aliyun.com/postgresql/repos/apt \${PGDG_CODENAME}-pgdg main' > /etc/apt/sources.list.d/pgdg.list\"
        wget --quiet -O - https://mirrors.aliyun.com/postgresql/repos/apt/ACCC4CF8.asc | apt-key add -
    else
        echo '使用PostgreSQL官方源...'
        sh -c \"echo 'deb https://mirrors.aliyun.com/postgresql/repos/apt \${PGDG_CODENAME}-pgdg main' > /etc/apt/sources.list.d/pgdg.list\"
        wget --quiet -O - https://mirrors.aliyun.com/postgresql/repos/apt/ACCC4CF8.asc | apt-key add -
    fi
    
    apt-get update -y

    echo ''
    echo '========================================='
    echo '步骤5: 收集所有包的递归依赖'
    echo '========================================='
    cd /download
    
    # 创建临时文件存储所有依赖
    ALL_DEPS_FILE='/tmp/all_deps.txt'
    > \$ALL_DEPS_FILE
    
    for pkg in $PACKAGES; do
        echo \"分析 \$pkg 的依赖...\"
        # 获取递归依赖，去重并追加到列表
        apt-rdepends \$pkg 2>/dev/null | grep -v '^ ' | sort -u >> \$ALL_DEPS_FILE
    done
    
    # 添加主包本身，最终去重
    for pkg in $PACKAGES; do
        echo \$pkg >> \$ALL_DEPS_FILE
    done
    sort -u \$ALL_DEPS_FILE -o \$ALL_DEPS_FILE
    
    TOTAL_DEPS=\$(wc -l < \$ALL_DEPS_FILE)
    echo \"✓ 共收集到 \$TOTAL_DEPS 个唯一包\"
    
    echo ''
    echo '========================================='
    echo '步骤6: 一次性批量下载所有包 (加速下载)'
    echo '========================================='
    
    echo \"共需下载 \$TOTAL_DEPS 个包，开始一次性下载...\"
    echo ''
    
    # 将所有包名一次性传给 apt-get download，让 apt 自己管理连接复用
    apt-get download \$(cat \$ALL_DEPS_FILE) 2>&1 | tail -5 || true
    
    echo ''
    echo '========================================='
    echo '下载完成! 统计信息'
    echo '========================================='
    
    DEB_COUNT=\$(ls -1 *.deb 2>/dev/null | wc -l)
    if [ \"\$DEB_COUNT\" -gt 0 ]; then
        echo \"✓ 成功下载: \$DEB_COUNT 个deb包\"
        echo \"总大小: \$(du -sh /download | cut -f1)\"
        echo ''
        echo '文件列表 (前20个):'
        ls -lh *.deb 2>/dev/null | head -20
        if [ \"\$DEB_COUNT\" -gt 20 ]; then
            echo \"... 还有 \$((DEB_COUNT - 20)) 个文件\"
        fi
    else
        echo '✗ 警告: 没有下载到任何deb包!'
    fi
    
    echo ''
    echo '========================================='
    echo '完成!'
    echo '========================================='
    echo \"文件位置: /download (映射到宿主机: ${DOWNLOAD_DIR})\"
"

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
echo "  scp -r root@\$(hostname):${DOWNLOAD_DIR} ./ubuntu-offline-packages"
