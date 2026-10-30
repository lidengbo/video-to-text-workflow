# ============================================================
#  视频转文字  一键脚本
#  用法:  .\scripts\transcribe.ps1 "视频路径" [-Format vtt,txt] [-Model medium] [-KeepVideo]
#  示例:  .\scripts\transcribe.ps1 ".\_inbox\abc.mp4"
#         .\scripts\transcribe.ps1 ".\_inbox\abc.mp4" -Format vtt,txt,srt -Model large-v3
#
#  第一次用先跑: .\scripts\setup.ps1
# ============================================================
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [Alias('InputPath')]
  [string]$Path,

  [string]$Format    = 'vtt',
  [string]$Model     = 'medium',
  [string]$Compute   = 'int8',
  [string]$Language  = 'zh',
  [string]$OutputDir = '',

  [Alias('KeepInput')]
  [switch]$KeepVideo
)

$ErrorActionPreference = 'Stop'

# --- 路径：默认全部相对于仓库根目录，整个文件夹可整体搬家 ---
# 工具装在别处时，设置环境变量 VTT_ROOT 指向那个目录
$Root = $env:VTT_ROOT
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }

$exe      = Join-Path $Root '_tools\app\Faster-Whisper-XXL\faster-whisper-xxl.exe'
$modelDir = Join-Path $Root '_tools\models'
$videoDir = Join-Path $Root '视频'

if (-not (Test-Path $exe)) {
  Write-Host "[错误] 找不到转写程序: $exe" -ForegroundColor Red
  Write-Host "       先运行: .\scripts\setup.ps1" -ForegroundColor Yellow
  exit 1
}
if (-not (Test-Path $Path)) {
  Write-Host "[错误] 找不到文件: $Path" -ForegroundColor Red
  exit 1
}

$file = Get-Item $Path
$stem = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
if (-not $OutputDir) { $OutputDir = Join-Path $videoDir $stem }
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " 文件   : $($file.Name)  ($([math]::Round($file.Length/1MB,2)) MB)"
Write-Host " 模型   : $Model ($Compute, CPU)"
Write-Host " 语言   : $Language"
Write-Host " 输出到 : $OutputDir"
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "开始转写（CPU 约 0.75 倍音频时长）..." -ForegroundColor Yellow

$fmtArgs = @()
foreach ($f in ($Format -split ',')) { $fmtArgs += @('--output_format', $f.Trim()) }

$Before = Get-Date
& $exe $file.FullName `
  --model $Model --model_dir $modelDir `
  --language $Language --device cpu --compute_type $Compute `
  --output_dir $OutputDir @fmtArgs

$code = $LASTEXITCODE
$Elapsed = (Get-Date) - $Before

Write-Host ""
if ($code -eq 0) {
  Write-Host "[完成] 耗时 $([math]::Round($Elapsed.TotalSeconds,1)) 秒" -ForegroundColor Green
  $produced = Get-ChildItem $OutputDir -File
  if ($produced) {
    $produced | ForEach-Object { Write-Host "  产出 -> $($_.Name)  ($([math]::Round($_.Length/1KB,1)) KB)" -ForegroundColor Green }
  } else {
    Write-Host "  [注意] 退出码为 0，但输出目录里没有文件，请检查 $OutputDir" -ForegroundColor Yellow
  }
  if (-not $KeepVideo) {
    Remove-Item $file.FullName -Force
    Write-Host "[已删除原视频] $($file.Name)   （想保留加 -KeepVideo）" -ForegroundColor DarkGray
  }
  Write-Host ""
  Write-Host "输出目录: $OutputDir" -ForegroundColor Cyan
} else {
  Write-Host "[失败] 退出码 $code" -ForegroundColor Red
  Write-Host "常见原因: 1) 模型文件缺失（首次运行需联网下载） 2) 参数写错 3) 磁盘满" -ForegroundColor Yellow
  exit $code
}
