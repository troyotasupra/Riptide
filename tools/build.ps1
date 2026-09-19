# Builds a standalone Windows copy of the game to build\Riptide.exe.
# Friends only need that one .exe (it has the game packed inside) — no Godot install.
# Windows refuses to run .ps1 files out of the box ("running scripts is disabled
# on this system"). -ExecutionPolicy Bypass applies to this one command only and
# changes nothing on the machine.
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1
param(
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" })
)

$project = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Force (Join-Path $project "build") | Out-Null
& $Godot --headless --path $project --export-release "Windows Desktop" (Join-Path $project "build\Riptide.exe")
if ($LASTEXITCODE -ne 0) { throw "Export failed (exit $LASTEXITCODE)" }
Get-ChildItem (Join-Path $project "build") | Select-Object Name, @{ Name = "MB"; Expression = { [math]::Round($_.Length / 1MB, 1) } }
