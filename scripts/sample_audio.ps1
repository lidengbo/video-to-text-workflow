param(
  [Parameter(Mandatory=$true)] [string]$InputPath,
  [string]$FfmpegPath = 'ffmpeg',
  [string]$FfprobePath = 'ffprobe',
  [Parameter(Mandatory=$true)] [string]$OutputDir,
  [int]$SampleSeconds = 8
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $InputPath)) { throw "Input not found: $InputPath" }
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$durationText = & $FfprobePath -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -- $InputPath
if ($LASTEXITCODE -ne 0) { throw 'ffprobe failed' }
$duration = [double]::Parse($durationText, [Globalization.CultureInfo]::InvariantCulture)
if ($duration -le 0) { throw 'Could not determine media duration' }

$sample = [Math]::Min([double]$SampleSeconds, [Math]::Max(1, $duration / 4))
$starts = @(
  0,
  [Math]::Max(0, ($duration / 2) - ($sample / 2)),
  [Math]::Max(0, $duration - $sample)
)

for ($i = 0; $i -lt $starts.Count; $i++) {
  $start = [Math]::Round($starts[$i], 3)
  $target = Join-Path $OutputDir ("sample-{0}.wav" -f ($i + 1))
  & $FfmpegPath -hide_banner -loglevel error -y -ss $start -i $InputPath -t $sample -vn -ac 1 -ar 16000 -c:a pcm_s16le -- $target
  if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed for sample $($i + 1)" }
  Write-Output $target
}
