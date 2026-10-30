<#
.SYNOPSIS
    一条命令跑完整条链路：分享链接或本地文件 → 下载 → 转写。

.DESCRIPTION
    链接会先用 yt-dlp 解析并下载到 _inbox，再按「平台-编号」归档到 视频/ 下并转写。
    本地文件则直接转写，归档目录用「local-文件名」。

.EXAMPLE
    .\scripts\run.ps1 "https://www.bilibili.com/video/BVxxxxxxxx"

.EXAMPLE
    .\scripts\run.ps1 ".\_inbox\我的视频.mp4" -KeepVideo

.EXAMPLE
    .\scripts\run.ps1 "https://..." -NoTranscribe
    只下载，不转写
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Source,

    [string]$Platform = '',
    [string]$Id = '',

    [string]$Model = 'medium',
    [string]$Format = 'vtt,txt',
    [string]$Language = 'zh',

    [switch]$KeepVideo,
    [switch]$NoTranscribe
)

$ErrorActionPreference = 'Stop'

$Root = $env:VTT_ROOT
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }

$inboxDir = Join-Path $Root '_inbox'
$videoDir = Join-Path $Root '视频'
foreach ($d in @($inboxDir, $videoDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

$transcribe = Join-Path $PSScriptRoot 'transcribe.ps1'
if (-not (Test-Path $transcribe)) { throw "找不到 transcribe.ps1: $transcribe" }

# ---------- 1. 拿到媒体文件 ----------
if (Test-Path $Source) {
    $media = (Resolve-Path $Source).Path
    if (-not $Platform) { $Platform = 'local' }
    if (-not $Id) { $Id = [System.IO.Path]::GetFileNameWithoutExtension($media) }
    Write-Host "[输入] 本地文件: $media" -ForegroundColor Cyan
} else {
    $ytdlp = Get-Command yt-dlp -ErrorAction SilentlyContinue
    if (-not $ytdlp) {
        Write-Host "[错误] 需要 yt-dlp 才能解析链接" -ForegroundColor Red
        Write-Host "       安装: winget install yt-dlp.yt-dlp" -ForegroundColor Yellow
        Write-Host "       或者先把视频下载到本地，再把这个文件路径作为参数" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "[解析] $Source" -ForegroundColor Cyan
    $raw = & yt-dlp --skip-download --no-playlist --print "%(extractor_key)s" --print "%(id)s" $Source 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $raw) {
        Write-Host "[错误] yt-dlp 解析失败。可能是链接失效、需要登录，或该站点暂不支持。" -ForegroundColor Red
        Write-Host "       可先手动下载视频，再用本地文件路径运行本脚本。" -ForegroundColor Yellow
        exit 1
    }
    $lines = @($raw | Where-Object { $_ -and ($_ -notmatch '^\[') })
    if (-not $Platform) { $Platform = $lines[0] }
    if (-not $Id) { $Id = $lines[1] }
    if (-not $Id) {
        Write-Host "[错误] 没能拿到视频编号，请用 -Id 手动指定" -ForegroundColor Red
        exit 1
    }

    $safeId = $Id -replace '[\\/:*?"<>|]', '-'
    Write-Host "[信息] 平台=$Platform  编号=$safeId" -ForegroundColor Cyan
    Write-Host "[下载] 保存到 _inbox ..." -ForegroundColor Yellow
    & yt-dlp --no-playlist -o "$inboxDir\$safeId.%(ext)s" $Source
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[错误] 下载失败（退出码 $LASTEXITCODE）" -ForegroundColor Red
        exit 1
    }
    $picked = Get-ChildItem $inboxDir -File | Where-Object { $_.BaseName -eq $safeId } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $picked) {
        Write-Host "[错误] 下载完成但没在 $inboxDir 找到 $safeId.*" -ForegroundColor Red
        exit 1
    }
    $media = $picked.FullName
    Write-Host "[下载完成] $($picked.Name)  ($([math]::Round($picked.Length/1MB,1)) MB)" -ForegroundColor Green
}

# ---------- 2. 归档目录：平台-编号 ----------
$safePlatform = $Platform -replace '[\\/:*?"<>|]', '-'
$safeIdFinal = $Id -replace '[\\/:*?"<>|]', '-'
$archiveDir = Join-Path $videoDir "$safePlatform-$safeIdFinal"
if (-not (Test-Path $archiveDir)) { New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null }

if ($NoTranscribe) {
    Write-Host ""
    Write-Host "[完成] 只下载不转写" -ForegroundColor Green
    Write-Host "  媒体: $media"
    Write-Host "  之后可运行: .\scripts\run.ps1 `"$media`" -Id $safeIdFinal -Platform $safePlatform"
    exit 0
}

# ---------- 3. 转写 ----------
Write-Host ""
$params = @{
    Path      = $media
    OutputDir = $archiveDir
    Model     = $Model
    Format    = $Format
    Language  = $Language
}
if ($KeepVideo) { $params.KeepVideo = $true }
if ($env:VTT_ROOT) { Write-Host "[提示] 使用 VTT_ROOT=$env:VTT_ROOT" -ForegroundColor DarkGray }

& $transcribe @params
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# ---------- 4. 下一步 ----------
Write-Host ""
Write-Host "归档目录: $archiveDir" -ForegroundColor Cyan
$vtt = Get-ChildItem $archiveDir -Filter *.vtt -ErrorAction SilentlyContinue | Select-Object -First 1
if ($vtt) {
    Write-Host "字幕文件: $($vtt.FullName)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "下一步：把这个 vtt 交给 AI（Claude Code / DSH / ChatGPT 都行）整理成 Markdown 笔记，" -ForegroundColor Yellow
    Write-Host "提示词见 README 的「从 VTT 到 Markdown 笔记」一节。" -ForegroundColor Yellow
} else {
    Write-Host "没找到 .vtt，可能转写未产生字幕（纯音乐或无人声）。" -ForegroundColor Yellow
}
