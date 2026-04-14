# CodeBuddy 项目配置

## 项目信息

- **项目名称**: ubuntu-deb-download-depends
- **描述**: Ubuntu 软件包离线下载与依赖分析工具
- **平台**: Windows/Linux

## 工具链

### 脚本工具

| 脚本                    | 平台        | 说明             |
| ----------------------- | ----------- | ---------------- |
| `download-packages.sh`  | Linux/macOS | 主体下载脚本     |
| `download-packages.bat` | Windows     | Windows 批处理版 |
| `download-packages.ps1` | Windows     | PowerShell 版    |
| `download-remote.sh`    | Linux       | 远程下载工具     |
| `download-simple.sh`    | Linux       | 简化版下载       |

### Docker 支持

| 文件                | 说明             |
| ------------------- | ---------------- |
| `Dockerfile`        | 完整版多阶段构建 |
| `Dockerfile.simple` | 简化版           |

## 常用命令

```bash
# Linux/macOS 下载
./download-packages.sh nginx postgresql-12

# Windows 下载
.\download-packages.ps1 -Packages nginx,postgresql-12

# Docker 构建
docker build -t ubuntu-offline:latest .

# Docker 运行
docker run -it ubuntu-offline:latest
```

## 镜像源

- **主源**: 清华大学镜像 (mirrors.tuna.tsinghua.edu.cn)
- **备用**: 阿里云镜像 (mirrors.aliyun.com)

## 开发说明

### 依赖环境

- bash / zsh / fish shell
- apt-rdepends (依赖分析)
- wget 或 curl
- dpkg-scanpackages (构建本地源)

### 目录结构

```
项目根目录/
├── 脚本工具/          # 下载脚本
├── 清华源配置说明.md  # 镜像源配置指南
├── README.md         # 项目说明
├── DOCKERFILE_README.md
└── ...
```

## 环境变量

| 变量              | 说明         | 默认值           |
| ----------------- | ------------ | ---------------- |
| `DEBIAN_FRONTEND` | 安装交互模式 | `noninteractive` |
| `MIRROR_URL`      | 镜像源地址   | 清华源           |

## 注意事项

1. 确保网络畅通，可访问镜像站
2. 离线安装需要完整下载所有依赖
3. Docker 构建需要足够磁盘空间 (~5GB)
4. PostgreSQL 需单独添加 pgdg 源
