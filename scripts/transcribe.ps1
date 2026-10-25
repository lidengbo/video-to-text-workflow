param(
  [Parameter(Mandatory=$true)] [string]$InputPath,
  [Parameter(Mandatory=$true)] [string]$OutputDir,
  [string]$WhisperPath = 'faster-whisper-xxl',
  [string]$ModelDir = '',
  [string]$Model = 'medium',
  [string]$Language = 'zh',
  [string]$ComputeType = 'int8',
  [switch]$KeepInput
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $InputPath)) { throw "Input not found: $InputPath" }
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$args = @($InputPath, '--model', $Model, '--language', $Language, '--device', 'cpu', '--compute_type', $ComputeType, '--output_dir', $OutputDir, '--output_format', 'vtt')
if ($ModelDir) { $args += @('--model_dir', $ModelDir) }

& $WhisperPath @args
if ($LASTEXITCODE -ne 0) { throw "Faster-Whisper failed with exit code $LASTEXITCODE" }
if (-not $KeepInput) { Remove-Item -LiteralPath $InputPath -Force }
