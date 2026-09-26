# Points the game at the machine running the Mirror server and picks your role.
#
# Usage: powershell -ExecutionPolicy Bypass -File scripts\set-mirror-host.ps1 <host-tailscale-ip> <host|join>
#   host: you run the web server and open spaces (a game server starts on your machine)
#   join: you connect to the host's server
param(
	[Parameter(Mandatory = $true)][string]$HostIp,
	[Parameter(Mandatory = $true)][ValidateSet("host", "join")][string]$Role
)
$ErrorActionPreference = "Stop"

$App = Join-Path (Split-Path -Parent $PSScriptRoot) "mirror-godot-app"
$Configs = Join-Path $App "addons\mirror_internal\env_configs"

# Replace the IPv4 address in both presets, then activate the chosen one.
foreach ($name in "tailscale-host.cfg", "tailscale-join.cfg") {
	$path = Join-Path $Configs $name
	$text = [IO.File]::ReadAllText($path)
	$text = [Regex]::Replace($text, '(http://|ws://|zone_server_host=")\d+\.\d+\.\d+\.\d+', "`${1}$HostIp")
	[IO.File]::WriteAllText($path, $text)
}
Copy-Item (Join-Path $Configs "tailscale-$Role.cfg") (Join-Path $App "override.cfg") -Force

Write-Host "Game set to '$Role' with the Mirror server at $HostIp."
