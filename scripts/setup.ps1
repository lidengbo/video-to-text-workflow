<#
.SYNOPSIS
    准备视频转文字工作流的本地工具链。

.DESCRIPTION
    检查并补齐运行所需的一切：Faster-Whisper-XXL（自带 ffmpeg）、模型目录、工作目录。
    首次运行需下载约 1.4 GB 安装包，解压后占用约 3 GB；模型另需约 1.5 GB。

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1

.EXAMPLE
    .\scripts\setup.ps1 -Force
    已安装也重新下载最新版

.EXAMPLE
    .\scripts\setup.ps1 -LocalPackage "D:\下载\Faster-Whisper-XXL_r245.4_windows.7z"
    GitHub 访问不通时，手动下好安装包再喂给脚本
#>
[CmdletBinding()]
param(
    [string]$Root,
    [string]$LocalPackage,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }

$appDir   = Join-Path $Root '_tools\app'
$modelDir = Join-Path $Root '_tools\models'
$dlDir    = Join-Path $Root '_tools\download'
$videoDir = Join-Path $Root '视频'
$inboxDir = Join-Path $Root '_inbox'
$exe      = Join-Path $appDir 'Faster-Whisper-XXL\faster-whisper-xxl.exe'

Write-Host ""
Write-Host "工作目录: $Root" -ForegroundColor Cyan
Write-Host "--------------------------------------------------"

foreach ($d in @($appDir, $modelDir, $dlDir, $videoDir, $inboxDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# ---------- 1. 转写程序 ----------
if ((Test-Path $exe) -and (-not $Force)) {
    Write-Host "[跳过] 转写程序已存在" -ForegroundColor Green
    Write-Host "       $exe" -ForegroundColor DarkGray
} else {
    # ---------- 取安装包 ----------
    if ($LocalPackage) {
        if (-not (Test-Path $LocalPackage)) { throw "本地安装包不存在: $LocalPackage" }
        $pkg = (Resolve-Path $LocalPackage).Path
        Write-Host "[跳过] 使用本地安装包: $pkg" -ForegroundColor Green
    } else {
        Write-Host "[查询] 获取 Faster-Whisper-XXL 最新 Windows 版..." -ForegroundColor Yellow
        $api = 'https://api.github.com/repos/Purfview/whisper-standalone-win/releases?per_page=15'
        try {
            $rels = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = 'video-to-text-setup' } -TimeoutSec 60
        } catch {
            throw "无法访问 GitHub API（$($_.Exception.Message)）。`n可以手动下载安装包后重跑：`n  .\scripts\setup.ps1 -LocalPackage D:\下载\Faster-Whisper-XXL_r245.4_windows.7z`n下载页: https://github.com/Purfview/whisper-standalone-win/releases"
        }

        $asset = $null
        foreach ($r in $rels) {
            foreach ($a in $r.assets) {
                if ($a.name -match '^Faster-Whisper-XXL_r[\d.]+_windows\.(7z|zip)$') { $asset = $a; break }
            }
            if ($asset) { break }
        }
        if (-not $asset) {
            throw '没找到 Windows 安装包。请手动从 https://github.com/Purfview/whisper-standalone-win/releases 下载后，用 -LocalPackage 指定路径。'
        }

        $pkg = Join-Path $dlDir $asset.name
        $sizeGB = [math]::Round($asset.size / 1GB, 2)
        Write-Host "[下载] $($asset.name)  ($sizeGB GB)" -ForegroundColor Yellow
        Write-Host "       视网速可能需要几分钟到几十分钟，中途别关窗口。" -ForegroundColor DarkGray

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        if (Test-Path $pkg) {
            Write-Host "[复用] 已有下载包，跳过下载步骤" -ForegroundColor Green
        } else {
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add('User-Agent', 'video-to-text-setup')
            $wc.DownloadFile($asset.browser_download_url, $pkg)
            Write-Host "[下载完成] 耗时 $([math]::Round($sw.Elapsed.TotalSeconds,0)) 秒" -ForegroundColor Green
        }
    }

    # ---------- 解压 ----------
    $ext = [System.IO.Path]::GetExtension($pkg).ToLower()
    if ($ext -eq '.zip') {
        Write-Host "[解压] 使用 Expand-Archive" -ForegroundColor Yellow
        Expand-Archive -Path $pkg -DestinationPath $appDir -Force
    } else {
        $sevenZip = $null
        $candidates = @('7z.exe', "$env:ProgramFiles\7-Zip\7z.exe")
        if (${env:ProgramFiles(x86)}) { $candidates += "${env:ProgramFiles(x86)}\7-Zip\7z.exe" }
        foreach ($c in $candidates) {
            $cmd = Get-Command $c -ErrorAction SilentlyContinue
            if ($cmd) { $sevenZip = $cmd.Source; break }
        }

        if ($sevenZip) {
            Write-Host "[解压] 使用 7-Zip: $sevenZip" -ForegroundColor Yellow
            & $sevenZip x $pkg "-o$appDir" -y | Out-Null
        } else {
            Write-Host "[解压] 使用系统自带 tar（bsdtar）" -ForegroundColor Yellow
            & tar.exe -xf $pkg -C $appDir
            if ($LASTEXITCODE -ne 0) {
                throw "解压失败。请安装 7-Zip 后重跑：`n  .\scripts\setup.ps1 -LocalPackage `"$pkg`"`n或手动把它解压到 $appDir"
            }
        }
    }

    if (-not (Test-Path $exe)) {
        throw "解压后仍找不到 $exe，请检查压缩包结构"
    }
    Write-Host "[完成] 转写程序已就位" -ForegroundColor Green
}

# ---------- 2. ffmpeg ----------
$ffmpeg = Join-Path $appDir 'Faster-Whisper-XXL\ffmpeg.exe'
if (Test-Path $ffmpeg) {
    Write-Host "[就绪] ffmpeg 随转写程序自带" -ForegroundColor Green
} else {
    Write-Host "[提示] 没找到自带 ffmpeg；抽取样本时需要 ffmpeg，可 winget install yt-dlp.FFmpeg" -ForegroundColor Yellow
}

# ---------- 3. 模型 ----------
$models = @()
if (Test-Path $modelDir) { $models = @(Get-ChildItem $modelDir -Directory -ErrorAction SilentlyContinue) }
if ($models.Count -eq 0) {
    Write-Host "[提示] 模型目录是空的" -ForegroundColor Yellow
    Write-Host "       首次转写会自动从 HuggingFace 下载 medium 模型（约 1.5 GB），需要联网。" -ForegroundColor DarkGray
    Write-Host "       也可以手动把模型放到: $modelDir" -ForegroundColor DarkGray
} else {
    $total = (Get-ChildItem $modelDir -Recurse -File | Measure-Object Length -Sum).Sum
    Write-Host "[就绪] 已有模型: $($models.Name -join ', ')  ($([math]::Round($total/1MB,0)) MB)" -ForegroundColor Green
}

# ---------- 4. 可选：链接解析 ----------
$ytdlp = Get-Command yt-dlp -ErrorAction SilentlyContinue
if ($ytdlp) {
    Write-Host "[就绪] yt-dlp: $($ytdlp.Source)" -ForegroundColor Green
} else {
    Write-Host "[可选] 没装 yt-dlp，无法直接由分享链接解析直链" -ForegroundColor Yellow
    Write-Host "       winget install yt-dlp.yt-dlp" -ForegroundColor DarkGray
}

# ---------- 5. 汇总 ----------
$freeGB = '未知'
try {
    $qualifier = Split-Path -Qualifier $Root
    if ($qualifier) {
        $driveLetter = $qualifier.TrimEnd(':')
        $freeGB = [math]::Round((Get-PSDrive $driveLetter).Free / 1GB, 1)
    }
} catch { }
Write-Host "--------------------------------------------------"
Write-Host "磁盘剩余: $freeGB GB" -ForegroundColor Cyan
Write-Host ""
Write-Host "下一步：" -ForegroundColor Cyan
Write-Host "  1. 把视频/音频放进 $inboxDir"
Write-Host "  2. .\scripts\transcribe.ps1 `".\_inbox\你的文件.mp4`""
Write-Host ""
Write-Host "提醒：不加 -KeepVideo 时，转写成功后会删除原文件。" -ForegroundColor Yellow
