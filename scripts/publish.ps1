<#
.SYNOPSIS
    把某个归档目录里的整理稿同步到 Markdown 知识库（Obsidian / Logseq / 普通文件夹都行）。

.DESCRIPTION
    整理稿（.md）通常是在 run.ps1 之后由 AI 或手工生成的，
    所以这一步要单独跑：生成完 md 再执行本脚本。

.EXAMPLE
    .\scripts\publish.ps1 -Archive ".\视频\抖音-hsV-lOZIH3o" -Vault "D:\我的笔记\视频解析"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Archive,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$Vault
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Archive)) { throw "找不到归档目录: $Archive" }

$archivePath = (Resolve-Path $Archive).Path
$archiveName = Split-Path $archivePath -Leaf
$target = Join-Path $Vault $archiveName

$files = @()
foreach ($pattern in @('*.md', '*.vtt')) {
    $files += @(Get-ChildItem $archivePath -Filter $pattern -File -ErrorAction SilentlyContinue)
}
if ($files.Count -eq 0) {
    Write-Host "[跳过] 归档目录里没有 .md 或 .vtt: $archivePath" -ForegroundColor Yellow
    exit 0
}

if (-not (Test-Path $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }

foreach ($f in $files) {
    Copy-Item -Path $f.FullName -Destination (Join-Path $target $f.Name) -Force
    Write-Host "  复制 -> $(Join-Path $target $f.Name)" -ForegroundColor Green
}

$hasMd = @($files | Where-Object { $_.Extension -eq '.md' }).Count
if ($hasMd -eq 0) {
    Write-Host "[提醒] 只同步了字幕，没有整理稿 .md。先把 vtt 整理成 md 再来一次。" -ForegroundColor Yellow
} else {
    Write-Host "[完成] 已同步 $($files.Count) 个文件到 $target" -ForegroundColor Green
}
