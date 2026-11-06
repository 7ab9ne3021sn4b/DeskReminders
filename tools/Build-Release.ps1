# Builds the download zip for a GitHub release.
#
# Run from the repository folder:
#   powershell -ExecutionPolicy Bypass -File tools\Build-Release.ps1
#
# Output: dist\DeskReminders-v<version>.zip and its SHA-256 checksum.
# Your own schedule.csv is never included.

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$app  = Join-Path $repo 'DeskReminders'

$versionLine = Select-String -LiteralPath (Join-Path $app 'DeskReminders.ps1') -Pattern "^\`$AppVersion\s*=\s*'([^']+)'" | Select-Object -First 1
if (-not $versionLine) { throw 'Could not find $AppVersion in DeskReminders.ps1' }
$version = $versionLine.Matches[0].Groups[1].Value

$dist  = Join-Path $repo 'dist'
$stage = Join-Path $dist 'stage'
$out   = Join-Path $dist "DeskReminders-v$version.zip"

if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $stage 'DeskReminders') -Force | Out-Null

$files = @(
    'DeskReminders.ps1', 'DeskReminders.ico', 'schedule.template.csv', 'shared-schedule.template.csv', 'README.txt',
    'Start-Reminders.cmd', 'Add-To-Startup.cmd', 'Remove-From-Startup.cmd'
)
foreach ($f in $files) { Copy-Item -LiteralPath (Join-Path $app $f) -Destination (Join-Path $stage 'DeskReminders') }
Copy-Item -LiteralPath (Join-Path $app 'sounds') -Destination (Join-Path $stage 'DeskReminders\sounds') -Recurse
Copy-Item -LiteralPath (Join-Path $app 'assets') -Destination (Join-Path $stage 'DeskReminders\assets') -Recurse
Copy-Item -LiteralPath (Join-Path $repo 'LICENSE') -Destination (Join-Path $stage 'DeskReminders\LICENSE.txt')

if (Test-Path $out) { Remove-Item $out -Force }
Compress-Archive -Path (Join-Path $stage 'DeskReminders') -DestinationPath $out
Remove-Item $stage -Recurse -Force

$hash = (Get-FileHash -LiteralPath $out -Algorithm SHA256).Hash
Write-Host ''
Write-Host "Built:   $out"
Write-Host "SHA-256: $hash"
Write-Host ''
Write-Host 'Paste the checksum into the release notes.'
