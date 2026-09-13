# Launches a host and N client windows side by side on this machine for co-op testing.
#   powershell -File tools\coop_test.ps1            # host + 1 client
#   powershell -File tools\coop_test.ps1 -Clients 2 -Seed 1234
param(
    [int]$Clients = 1,
    [int]$Seed = 1234,
    [int]$Port = 24570,
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { "C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe" })
)

$project = Split-Path -Parent $PSScriptRoot
$width = 800
$height = 450

Start-Process -FilePath $Godot -ArgumentList @("--path", "`"$project`"", "--", "--host", "--port=$Port", "--name=Host", "--seed=$Seed", "--window=0,40,$width,$height")
Start-Sleep -Seconds 2

for ($i = 1; $i -le $Clients; $i++) {
    $x = ($i % 2) * $width
    $y = 40 + [math]::Floor($i / 2) * ($height + 40)
    Start-Process -FilePath $Godot -ArgumentList @("--path", "`"$project`"", "--", "--join=127.0.0.1", "--port=$Port", "--name=Crew$i", "--window=$x,$y,$width,$height")
}
