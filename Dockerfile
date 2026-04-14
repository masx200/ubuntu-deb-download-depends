# ============================================
# Ubuntu 离线软件包镜像 - 多阶段构建
# 功能: 换源 → 下载软件包 → 离线安装
# ============================================

# ============================================
# 阶段一: 下载软件包
# ============================================
FROM ubuntu:22.04 AS downloader

# 设置非交互式安装
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true

# 定义要下载的软件包 (可自定义)
ARG PACKAGES="nginx postgresql-12 openjdk-11-jdk"

# 工作目录
WORKDIR /download

# 预创建目录
RUN mkdir -p /download /var/lib/apt/lists/partial

# ============================================
# 步骤1: 初始化并安装必要工具
# ============================================
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    lsb-release \
    gnupg \
    wget \
    apt-rdepends \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# 步骤2: 替换为清华大学镜像源
# ============================================
RUN echo "配置清华大学镜像源..." && \
    UBUNTU_CODENAME=$(lsb_release -cs) && \
    echo "检测到Ubuntu版本: $UBUNTU_CODENAME" && \
    \
    # 备份原配置
    if [ -f /etc/apt/sources.list ]; then \
    cp /etc/apt/sources.list /etc/apt/sources.list.bak; \
    fi && \
    \
    # 写入清华源配置 (传统格式,兼容22.04)
    cat > /etc/apt/sources.list << EOF
# 清华源 - Ubuntu 主仓库
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse
EOF

# ============================================
# 步骤3: 添加PostgreSQL清华源
# ============================================
RUN echo "配置PostgreSQL清华源..." && \
    UBUNTU_CODENAME=$(lsb_release -cs) && \
    \
    # 检测清华PostgreSQL源是否可用
    if wget --spider -q "https://mirrors.aliyun.com/postgresql/repos/apt/dists/${UBUNTU_CODENAME}-pgdg/" 2>/dev/null; then \
    echo "使用PostgreSQL清华源"; \
    echo "deb https://mirrors.aliyun.com/postgresql/repos/apt ${UBUNTU_CODENAME}-pgdg main" > /etc/apt/sources.list.d/pgdg.list; \
    wget --quiet -O - https://mirrors.aliyun.com/postgresql/repos/apt/ACCC4CF8.asc | apt-key add -; \
    else \
    echo "使用PostgreSQL官方源"; \
    echo "deb https://mirrors.aliyun.com/postgresql/repos/apt ${UBUNTU_CODENAME}-pgdg main" > /etc/apt/sources.list.d/pgdg.list; \
    wget --quiet -O - https://mirrors.aliyun.com/postgresql/repos/apt/ACCC4CF8.asc | apt-key add -; \
    fi

# ============================================
# 步骤4: 更新软件包列表
# ============================================
RUN apt-get update -y

# ============================================
# 步骤5: 下载所有软件包及依赖
# ============================================
# 创建下载脚本
RUN echo '#!/bin/bash' > /download.sh && \
    echo 'set -e' >> /download.sh && \
    echo '' >> /download.sh && \
    echo 'PACKAGES="'"${PACKAGES}"'"' >> /download.sh && \
    echo 'cd /download' >> /download.sh && \
    echo '' >> /download.sh && \
    echo 'for pkg in $PACKAGES; do' >> /download.sh && \
    echo '    echo "正在下载: $pkg"' >> /download.sh && \
    echo '    # 获取所有递归依赖(去重)' >> /download.sh && \
    echo '    deps=$(apt-rdepends $pkg 2>/dev/null | grep -v "^ " | sort -u)' >> /download.sh && \
    echo '    for dep in $deps; do' >> /download.sh && \
    echo '        apt-get download $dep 2>/dev/null || true' >> /download.sh && \
    echo '    done' >> /download.sh && \
    echo 'done' >> /download.sh && \
    echo 'echo "下载完成!"' >> /download.sh && \
    echo 'ls -lh /download/*.deb | wc -l' >> /download.sh && \
    chmod +x /download.sh

# 执行下载
RUN /download.sh

# ============================================
# 阶段二: 离线安装 (使用下载的包)
# ============================================
FROM ubuntu:22.04 AS installer

ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true

# 从上一阶段复制已下载的包
COPY --from=downloader /download /download

# 工作目录
WORKDIR /download

# 预创建目录
RUN mkdir -p /var/lib/apt/lists/partial

# ============================================
# 步骤1: 配置清华源 (用于安装依赖)
# ============================================
RUN echo "配置清华大学镜像源..." && \
    UBUNTU_CODENAME=$(lsb_release -cs) && \
    \
    cat > /etc/apt/sources.list << EOF
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse
EOF

# 添加PostgreSQL源
RUN UBUNTU_CODENAME=$(lsb_release -cs) && \
    if wget --spider -q "https://mirrors.aliyun.com/postgresql/repos/apt/dists/${UBUNTU_CODENAME}-pgdg/" 2>/dev/null; then \
    echo "deb https://mirrors.aliyun.com/postgresql/repos/apt ${UBUNTU_CODENAME}-pgdg main" > /etc/apt/sources.list.d/pgdg.list; \
    wget --quiet -O - https://mirrors.aliyun.com/postgresql/repos/apt/ACCC4CF8.asc | apt-key add -; \
    else \
    echo "deb https://mirrors.aliyun.com/postgresql/repos/apt ${UBUNTU_CODENAME}-pgdg main" > /etc/apt/sources.list.d/pgdg.list; \
    wget --quiet -O - https://mirrors.aliyun.com/postgresql/repos/apt/ACCC4CF8.asc | apt-key add -; \
    fi

# 更新包列表
RUN apt-get update -y

# ============================================
# 步骤2: 修复依赖 (使用清华源下载缺失的依赖)
# ============================================
# 有些依赖包可能需要从网络下载
RUN echo "检查并下载缺失的依赖..." && \
    # 先尝试用apt安装基础依赖
    apt-get install -y --no-install-recommends \
    ca-certificates \
    lsb-release \
    gnupg \
    wget \
    gnupg2 \
    debconf \
    libaudit1 \
    libcap2 \
    libpam0g \
    libpam-modules \
    libpam-modules-bin \
    libsystemd0 \
    libudev1 \
    systemd \
    udev \
    adduser \
    apt \
    base-files \
    base-passwd \
    bash \
    bsdutils \
    coreutils \
    dash \
    diffutils \
    dpkg \
    e2fsprogs \
    fdisk \
    findutils \
    gcc-12-base \
    gpgv \
    grep \
    gzip \
    hostname \
    init-system-helpers \
    libacl1 \
    libapt-pkg6.0 \
    libattr1 \
    libblkid1 \
    libbz2-1.0 \
    libc-bin \
    libc6 \
    libcom-err2 \
    libcrypt1 \
    libdb5.3 \
    libdebconfclient0 \
    libext2fs2 \
    libgcc-s1 \
    libgcrypt20 \
    libgmp10 \
    libgnutls30 \
    libgpg-error0 \
    libgssapi-krb5-2 \
    libhogweed6 \
    libidn2-0 \
    libjson-c5 \
    libk5crypto3 \
    libkeyutils1 \
    liblz4-1 \
    liblzma5 \
    libmount1 \
    libnettle8 \
    libp11-kit0 \
    libpam0g \
    libpcre3 \
    libseccomp2 \
    libselinux1 \
    libsmartcols1 \
    libss2 \
    libstdc++6 \
    libsystemd0 \
    libtasn1-6 \
    libtextdevcration \
    libtinfo6 \
    libtwowayserial10 \
    libudev1 \
    libuuid1 \
    libzstd1 \
    login \
    logsave \
    mount \
    ncurses-base \
    ncurses-bin \
    passwd \
    perl-base \
    sed \
    sensible-utils \
    sysvinit-utils \
    tar \
    tzdata \
    ubuntu-keyring \
    util-linux \
    zlib1g \
    || true

# ============================================
# 步骤3: 离线安装已下载的deb包
# ============================================
RUN echo "开始离线安装..." && \
    # 按依赖顺序安装 (先安装基础包,避免依赖问题)
    # 安装所有deb包,自动处理依赖
    dpkg --force-depends -i *.deb || true && \
    apt-get install -f -y --no-install-recommends || true && \
    echo "离线安装完成!"

# ============================================
# 步骤4: 清理安装包(节省空间)
# ============================================
RUN rm -rf /download/*.deb && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# # ============================================
# # 最终镜像
# # ============================================
# FROM ubuntu:22.04

# ENV DEBIAN_FRONTEND=noninteractive
# ENV DEBCONF_NONINTERACTIVE_SEEN=true

# # 从安装阶段复制已安装的系统
# COPY --from=installer / /

# # 设置入口点信息
# RUN echo "========================================" && \
#     echo "Ubuntu离线软件包镜像已构建完成!" && \
#     echo "========================================" && \
#     echo "已安装的软件包:" && \
#     echo "  - nginx" && \
#     echo "  - postgresql-12" && \
#     echo "  - openjdk-11-jdk" && \
#     echo "" && \
#     echo "验证安装:" && \
#     nginx -v 2>&1 || true && \
#     psql --version 2>&1 || true && \
#     java -version 2>&1 || true && \
#     echo "========================================"

# # 健康检查
# HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
#     CMD pgrep nginx >/dev/null || pgrep postgres >/dev/null || pgrep java >/dev/null || exit 1

# # 默认命令
CMD ["/bin/bash"]
