<#
.SYNOPSIS
    一键安装：准备工具链 + 安装 yt-dlp。

.DESCRIPTION
    通常由仓库根目录的 安装.bat 双击调用，也可以直接命令行运行。
    重复运行是安全的：已装好的部分会跳过。

.EXAMPLE
    .\scripts\install.ps1

.EXAMPLE
    .\scripts\install.ps1 -NoYtdlp
    不自动装 yt-dlp（只想用本地视频文件时）
#>
[CmdletBinding()]
param(
    [switch]$NoYtdlp,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$setup = Join-Path $PSScriptRoot 'setup.ps1'

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Video to Text Workflow  一键安装" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  安装目录: $Root" -ForegroundColor DarkGray
Write-Host "  预计占用: 约 5.8 GB（工具链 4.3 GB + 模型 1.5 GB）" -ForegroundColor DarkGray

if (-not (Test-Path $setup)) { throw "找不到 setup.ps1: $setup" }

# ---------- 1. 工具链 ----------
Write-Host ""
Write-Host "[1/2] 准备转写工具链 ..." -ForegroundColor Yellow
if ($Force) {
    & $setup -Root $Root -Force
} else {
    & $setup -Root $Root
}
if (-not $?) { throw "工具链安装失败，请查看上面的报错。" }

# ---------- 2. yt-dlp ----------
Write-Host ""
Write-Host "[2/2] 检查 yt-dlp ..." -ForegroundColor Yellow
$ytdlp = Get-Command yt-dlp -ErrorAction SilentlyContinue
if ($ytdlp) {
    Write-Host "[就绪] 已安装: $($ytdlp.Source)" -ForegroundColor Green
} elseif ($NoYtdlp) {
    Write-Host "[跳过] 按 -NoYtdlp 要求不安装（只用本地文件时可跳过）" -ForegroundColor Yellow
} else {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Host "[提示] 系统没有 winget，请手动安装 yt-dlp:" -ForegroundColor Yellow
        Write-Host "       https://github.com/yt-dlp/yt-dlp/releases" -ForegroundColor DarkGray
    } else {
        Write-Host "[安装] 通过 winget 安装 yt-dlp ..." -ForegroundColor Yellow
        & winget install --id yt-dlp.yt-dlp --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[完成] yt-dlp 已安装（新开的终端才会在 PATH 里生效）" -ForegroundColor Green
        } else {
            Write-Host "[失败] winget 安装返回 $LASTEXITCODE，可手动安装：" -ForegroundColor Yellow
            Write-Host "        winget install yt-dlp.yt-dlp" -ForegroundColor DarkGray
        }
    }
}

# ---------- 收尾 ----------
Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " 安装完成，怎么用：" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  有视频链接（B 站等）：" -ForegroundColor Cyan
Write-Host '    .\scripts\run.ps1 "https://www.bilibili.com/video/BVxxxxxxxx"' -ForegroundColor White
Write-Host ""
Write-Host "  有本地视频文件：" -ForegroundColor Cyan
Write-Host '    .\scripts\run.ps1 "D:\我的视频.mp4" -KeepVideo' -ForegroundColor White
Write-Host ""
Write-Host "  第一次转写会自动下载模型（约 1.5 GB），需要联网，慢几分钟。" -ForegroundColor DarkGray
Write-Host ""
