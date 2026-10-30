<#
.SYNOPSIS
    一条命令跑完整条链路：分享链接或本地文件 → 检测平台字幕 → 决定是否转写。

.DESCRIPTION
    默认先探测平台是否提供中文字幕：
      - 有可用字幕：直接用它，跳过 CPU 转写（更快、专有名词更准）
      - 没有字幕：照旧下载媒体并用 Faster-Whisper 转写
    平台字幕默认只认人工上传的；要接受自动生成的字幕，加 -AllowAutoSubs。

.EXAMPLE
    .\scripts\run.ps1 "https://www.bilibili.com/video/BVxxxxxxxx"

.EXAMPLE
    .\scripts\run.ps1 "https://..." -AllowAutoSubs
    平台只有自动字幕时也接受

.EXAMPLE
    .\scripts\run.ps1 "https://..." -SkipSubsCheck
    不查字幕，直接下载并转写

.EXAMPLE
    .\scripts\run.ps1 ".\_inbox\我的视频.mp4" -KeepVideo

.EXAMPLE
    .\scripts\run.ps1 "https://..." -NoTranscribe
    只下载，不转写

.EXAMPLE
    .\scripts\run.ps1 "https://..." -Vault "D:\我的笔记\视频解析"
    转完顺便把已有的 .md/.vtt 同步到知识库目录
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
    [string]$Vault = '',

    [string[]]$SubLangs = @('zh-Hans', 'zh-CN', 'zh', 'zh-Hant', 'zh-TW'),

    [switch]$SkipSubsCheck,
    [switch]$AllowAutoSubs,
    [switch]$KeepVideo,
    [switch]$NoTranscribe,

    [string]$CookiesFrom = ''
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

$media = $null
$subFile = $null
$subSource = ''

# ---------- 1. 拿到媒体文件 / 平台字幕 ----------
if (Test-Path $Source) {
    $media = (Resolve-Path $Source).Path
    if (-not $Platform) { $Platform = 'local' }
    if (-not $Id) { $Id = [System.IO.Path]::GetFileNameWithoutExtension($media) }
    Write-Host "[输入] 本地文件: $media" -ForegroundColor Cyan
    Write-Host "[提示] 本地文件没有平台字幕可查，直接走转写" -ForegroundColor DarkGray
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
        Write-Host "       需要登录态时试试: -CookiesFrom chrome" -ForegroundColor Yellow
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

    # --- 1a. 探测平台字幕 ---
    if (-not $SkipSubsCheck) {
        $common = @('--no-playlist', '--skip-download', '--sub-format', 'vtt', '--sub-langs', ($SubLangs -join ','), '-o', "$inboxDir\$safeId.%(ext)s")
        if ($CookiesFrom) { $common += @('--cookies-from-browser', $CookiesFrom) }

        Write-Host "[检测] 查找平台中文字幕 ..." -ForegroundColor Cyan
        $t0 = Get-Date

        # 第一轮：只要人工上传的字幕
        $null = & yt-dlp @common --write-subs $Source 2>$null
        $found = Get-ChildItem $inboxDir -File -Filter "$safeId*.vtt" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $t0 } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($found) {
            $subFile = $found.FullName
            $subSource = '平台字幕（人工）'
        } elseif ($AllowAutoSubs) {
            # 第二轮：接受自动生成的字幕
            $t1 = Get-Date
            $null = & yt-dlp @common --write-subs --write-auto-subs $Source 2>$null
            $found = Get-ChildItem $inboxDir -File -Filter "$safeId*.vtt" -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -ge $t1 } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($found) {
                $subFile = $found.FullName
                $subSource = '平台字幕（自动生成）'
            }
        }

        if ($subFile) {
            Write-Host "[命中] $subSource，可跳过转写" -ForegroundColor Green
        } else {
            $hint = '没有可用平台字幕，走转写'
            if (-not $AllowAutoSubs) { $hint += '（自动字幕需加 -AllowAutoSubs）' }
            Write-Host "[未命中] $hint" -ForegroundColor Yellow
        }
    }

    # --- 1b. 需要媒体时再下载 ---
    if (-not $subFile -or $KeepVideo) {
        Write-Host "[下载] 保存到 _inbox ..." -ForegroundColor Yellow
        & yt-dlp --no-playlist -o "$inboxDir\$safeId.%(ext)s" $Source
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[错误] 下载失败（退出码 $LASTEXITCODE）" -ForegroundColor Red
            exit 1
        }
        $picked = Get-ChildItem $inboxDir -File | Where-Object { $_.BaseName -eq $safeId -and $_.Extension -ne '.vtt' } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $picked) {
            Write-Host "[错误] 下载完成但没在 $inboxDir 找到 $safeId.*" -ForegroundColor Red
            exit 1
        }
        $media = $picked.FullName
        Write-Host "[下载完成] $($picked.Name)  ($([math]::Round($picked.Length/1MB,1)) MB)" -ForegroundColor Green
    }
}

# ---------- 2. 归档目录：平台-编号 ----------
$safePlatform = $Platform -replace '[\\/:*?"<>|]', '-'
$safeIdFinal = $Id -replace '[\\/:*?"<>|]', '-'
$archiveDir = Join-Path $videoDir "$safePlatform-$safeIdFinal"
if (-not (Test-Path $archiveDir)) { New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null }

# ---------- 3a. 有平台字幕：直接用 ----------
if ($subFile) {
    $destVtt = Join-Path $archiveDir "$safeIdFinal.vtt"
    Copy-Item -Path $subFile -Destination $destVtt -Force
    Write-Host "[归档] 字幕 -> $destVtt" -ForegroundColor Green

    if ($media -and $KeepVideo) {
        $destMedia = Join-Path $archiveDir (Split-Path $media -Leaf)
        if (-not (Test-Path $destMedia)) { Copy-Item -Path $media -Destination $destMedia -Force }
        Write-Host "[归档] 媒体 -> $destMedia" -ForegroundColor Green
    }

    $srcMd = Join-Path $archiveDir '来源.md'
    if (-not (Test-Path $srcMd)) {
        $today = Get-Date -Format 'yyyy-MM-dd'
        $linesMd = @(
            '---',
            "platform: $safePlatform",
            "vid: `"$safeIdFinal`"",
            "source: `"$Source`"",
            "字幕来源: `"$subSource`"",
            "整理日期: $today",
            '转写日期: 无（使用平台字幕）',
            '---',
            '',
            '# 来源记录',
            '',
            "## 解析与保存情况",
            '',
            "- 原始链接：$Source",
            "- 平台：$safePlatform",
            "- 编号：$safeIdFinal",
            "- 字幕来源：$subSource",
            "- 是否转写：否，直接使用平台字幕",
            '',
            '## 文件位置',
            '',
            "- 归档目录：``$archiveDir``",
            "- 字幕：``$destVtt``"
        )
        Set-Content -Path $srcMd -Value ($linesMd -join "`r`n") -Encoding UTF8
        Write-Host "[记录] 已写入 来源.md" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "归档目录: $archiveDir" -ForegroundColor Cyan
    Write-Host "字幕文件: $destVtt" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "下一步：把 vtt 交给 AI 整理成 Markdown 笔记，提示词见 README。" -ForegroundColor Yellow
    Write-Host "提醒：平台字幕质量参差，专有名词和数字仍建议核对画面。" -ForegroundColor DarkYellow

    if ($Vault) {
        Write-Host ""
        $publish = Join-Path $PSScriptRoot 'publish.ps1'
        if (Test-Path $publish) { & $publish -Archive $archiveDir -Vault $Vault }
    }
    exit 0
}

if ($NoTranscribe) {
    Write-Host ""
    Write-Host "[完成] 只下载不转写" -ForegroundColor Green
    Write-Host "  媒体: $media"
    exit 0
}

# ---------- 3b. 无字幕：转写 ----------
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

# ---------- 5. 可选：同步到知识库 ----------
if ($Vault) {
    Write-Host ""
    $publish = Join-Path $PSScriptRoot 'publish.ps1'
    if (Test-Path $publish) {
        & $publish -Archive $archiveDir -Vault $Vault
    } else {
        Write-Host "[警告] 找不到 publish.ps1，跳过同步" -ForegroundColor Yellow
    }
}
