# Docker 镜像构建说明

## 📦 文件说明

| 文件                | 说明                                       |
| ------------------- | ------------------------------------------ |
| `Dockerfile`        | 完整版，功能全面，支持自动检测 Ubuntu 版本 |
| `Dockerfile.simple` | 简化版，代码精简，适合快速使用             |

## 🚀 快速开始

### 1. 构建镜像

```bash
# 构建完整版
docker build -t ubuntu-offline:latest .

# 构建简化版
docker build -f Dockerfile.simple -t ubuntu-offline:simple .
```

### 2. 运行容器

```bash
# 交互式运行
docker run -it ubuntu-offline:latest

# 后台运行
docker run -d ubuntu-offline:latest
```

### 3. 验证安装

```bash
docker run ubuntu-offline:latest bash -c "nginx -v && psql --version && java -version"
```

## 📋 构建流程

```
┌─────────────────────────────────────────┐
│  阶段1: builder                          │
│  ├─ 换源 (清华源)                        │
│  ├─ 安装 apt-rdepends                    │
│  ├─ 下载 nginx + 依赖                     │
│  ├─ 下载 postgresql-12 + 依赖            │
│  └─ 下载 openjdk-11-jdk + 依赖           │
└────────────────┬────────────────────────┘
                 │ COPY packages
                 ▼
┌─────────────────────────────────────────┐
│  阶段2: installer                        │
│  ├─ 配置清华源                           │
│  ├─ 安装基础依赖                         │
│  ├─ dpkg -i *.deb (离线安装)             │
│  └─ apt-get install -f (修复依赖)        │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│  最终镜像 (包含已安装的软件)              │
│  ✓ nginx                                 │
│  ✓ postgresql-12                         │
│  ✓ openjdk-11-jdk                        │
└─────────────────────────────────────────┘
```

## ⚙️ 自定义软件包

编辑 `Dockerfile.simple`，修改这一行：

```dockerfile
# 原配置
for pkg in nginx postgresql-12 openjdk-11-jdk; do

# 自定义示例
for pkg in nginx redis-server mysql-server; do
```

## 📊 镜像大小

| 阶段      | 内容           | 预计大小 |
| --------- | -------------- | -------- |
| builder   | 下载的 .deb 包 | ~800MB   |
| installer | 安装后         | ~1.5GB   |
| 最终镜像  | 清理后         | ~1.2GB   |

## 🔧 高级用法

### 只构建下载阶段（保存离线包）

```bash
docker build --target builder -t ubuntu-packages .
docker run -v $(pwd)/packages:/packages ubuntu-packages
```

### 多架构构建

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t your-image .
```

## ❗ 注意事项

1. **构建时间**: 完整构建约 15-30 分钟
2. **磁盘空间**: 确保至少 5GB 可用空间
3. **网络**: 构建过程中需要网络下载依赖
4. **Ubuntu 版本**: 当前默认 24.04 (noble)，可修改为其他版本
