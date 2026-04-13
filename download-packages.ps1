# Ubuntu离线软件包下载工具 - PowerShell版本
# 通过SSH连接到远程服务器，在Docker中下载软件包

$RemoteHost = "**************"
$RemoteUser = "root"
$DownloadDir = "/tmp/offline-packages"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Ubuntu离线软件包下载工具 (PowerShell版)" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "即将连接到 ${RemoteUser}@${RemoteHost}" -ForegroundColor Yellow
Write-Host ""

# 检查SSH是否可用
try {
    $sshCheck = ssh -o ConnectTimeout=5 -o BatchMode=yes ${RemoteUser}@${RemoteHost} "echo OK" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "SSH连接失败"
    }
    Write-Host "✓ SSH连接正常" -ForegroundColor Green
} catch {
    Write-Host "✗ 错误: 无法连接到远程服务器" -ForegroundColor Red
    Write-Host "请检查:" -ForegroundColor Yellow
    Write-Host "  1. 远程服务器是否开机" -ForegroundColor Yellow
    Write-Host "  2. SSH服务是否运行" -ForegroundColor Yellow
    Write-Host "  3. 网络连接是否正常" -ForegroundColor Yellow
    pause
    exit 1
}

# 检查Docker
Write-Host ""
Write-Host "检查Docker环境..." -ForegroundColor Yellow
try {
    $dockerVersion = ssh ${RemoteUser}@${RemoteHost} "docker --version" 2>&1
    Write-Host "✓ $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker未安装或无法访问" -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""
Write-Host "开始执行下载任务..." -ForegroundColor Yellow
Write-Host ""

# 读取并执行远程脚本
if (Test-Path ".\download-remote.sh") {
    $scriptContent = Get-Content ".\download-remote.sh" -Raw
    
    # 在远程服务器上执行
    $result = ssh ${RemoteUser}@${RemoteHost} "bash -s" 
    
    # 显示输出
    $result | ForEach-Object { Write-Host $_ }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host "操作完成!" -ForegroundColor Green
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "所有deb包已下载到远程服务器: ${DownloadDir}" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "下一步操作:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. 查看下载的文件:" -ForegroundColor White
        Write-Host "   ssh ${RemoteUser}@${RemoteHost} `"ls -lh ${DownloadDir}/*.deb`"" -ForegroundColor Gray
        Write-Host ""
        Write-Host "2. 复制到本地:" -ForegroundColor White
        Write-Host "   scp -r ${RemoteUser}@${RemoteHost}:${DownloadDir} .\ubuntu-offline-packages" -ForegroundColor Gray
        Write-Host ""
        Write-Host "3. 传输到离线机器并安装:" -ForegroundColor White
        Write-Host "   sudo dpkg -i *.deb" -ForegroundColor Gray
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "✗ 下载过程中出现错误" -ForegroundColor Red
        Write-Host ""
    }
} else {
    Write-Host ""
    Write-Host "✗ 错误: 找不到 download-remote.sh 脚本" -ForegroundColor Red
    Write-Host "请确保该脚本与当前脚本在同一目录" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "按任意键继续..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
