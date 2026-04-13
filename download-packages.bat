@echo off
chcp 65001 >nul
REM Ubuntu离线软件包下载工具 - Windows版本
REM 通过SSH连接到远程服务器，在Docker中下载软件包

set REMOTE_HOST=192.168.31.240
set REMOTE_USER=root

echo =========================================
echo Ubuntu离线软件包下载工具 (Windows版)
echo =========================================
echo.
echo 即将连接到 %REMOTE_USER%@%REMOTE_HOST%
echo.
pause

echo.
echo 步骤1: 检查SSH连接...
ssh %REMOTE_USER%@%REMOTE_HOST% "echo SSH连接成功 && docker --version"
if errorlevel 1 (
    echo 错误: 无法连接到远程服务器或Docker未安装
    pause
    exit /b 1
)

echo.
echo 步骤2: 在远程服务器上执行下载任务...
ssh %REMOTE_USER%@%REMOTE_HOST% "bash -s" < download-remote.sh

if errorlevel 1 (
    echo.
    echo 错误: 下载过程中出现错误
    pause
    exit /b 1
)

echo.
echo =========================================
echo 操作完成!
echo =========================================
echo.
echo 所有deb包已下载到远程服务器: /tmp/offline-packages
echo.
echo 下一步操作:
echo 1. 查看下载的文件:
echo    ssh %REMOTE_USER%@%REMOTE_HOST% "ls -lh /tmp/offline-packages/*.deb"
echo.
echo 2. 复制到本地:
echo    scp -r %REMOTE_USER%@%REMOTE_HOST%:/tmp/offline-packages .\ubuntu-offline-packages
echo.
echo 3. 传输到离线机器并安装:
echo    sudo dpkg -i *.deb
echo.
pause
