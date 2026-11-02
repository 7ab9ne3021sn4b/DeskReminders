# Fills in your GitHub username (and optionally a Ko-fi username) everywhere they're needed.
# Run once, from the repository folder:
#   powershell -ExecutionPolicy Bypass -File tools\Set-Names.ps1 -GitHub yourname

param(
    [Parameter(Mandatory = $true)][string]$GitHub,
    [string]$KoFi = '7ab9ne3021sn4b'
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$exts = @('.md', '.txt', '.ps1', '.yml', '.csv', '.cmd')
$changed = 0

Get-ChildItem -LiteralPath $repo -Recurse -File -Force |
    Where-Object { $exts -contains $_.Extension -and $_.FullName -notmatch '\\(\.git|dist)\\' -and $_.Name -ne 'Set-Names.ps1' } |
    ForEach-Object {
        $text = [System.IO.File]::ReadAllText($_.FullName)
        $new = $text.Replace('GITHUB_USERNAME', $GitHub).Replace('KOFI_USERNAME', $KoFi)
        if ($new -ne $text) {
            [System.IO.File]::WriteAllText($_.FullName, $new, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "Updated $($_.FullName.Substring($repo.Length + 1))"
            $changed++
        }
    }
Write-Host "$changed file(s) updated."
