# One command for friends on Windows: installs Tailscale and the build tools if
# missing, builds the Mirror fork of Godot, points the game at the host and
# imports the project. Safe to rerun; steps that are already done are quick.
#
# Usage (from the repo root, in PowerShell):
#   powershell -ExecutionPolicy Bypass -File scripts\setup-friend.ps1 [host-tailscale-ip]
#   Defaults to the host IP committed in the tailscale-join preset.
param([string]$HostIp)
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$JoinPreset = Join-Path $Root "mirror-godot-app\addons\mirror_internal\env_configs\tailscale-join.cfg"
if (-not $HostIp) {
	$HostIp = ([Regex]::Match([IO.File]::ReadAllText($JoinPreset), 'zone_server_host="([0-9.]+)"')).Groups[1].Value
}

# --- Tailscale ----------------------------------------------------------------
$tailscale = "$env:ProgramFiles\Tailscale\tailscale.exe"
if (-not (Test-Path $tailscale)) {
	winget install --id Tailscale.Tailscale -e --accept-source-agreements --accept-package-agreements
}
& $tailscale ip -4 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
	Write-Host "Log in to Tailscale (tray icon, or the browser window that opens), then run this script again."
	& $tailscale up
	exit 1
}

# --- Engine -------------------------------------------------------------------
& (Join-Path $PSScriptRoot "build-engine-windows.ps1")

# --- Game config + first import ----------------------------------------------
& (Join-Path $PSScriptRoot "set-mirror-host.ps1") -HostIp $HostIp -Role join
# The first import can end early when Godot restarts itself, so run a second pass.
& (Join-Path $PSScriptRoot "play.ps1") -Import
& (Join-Path $PSScriptRoot "play.ps1") -Import

try {
	Invoke-WebRequest -Uri "http://${HostIp}:9000/" -TimeoutSec 5 -UseBasicParsing | Out-Null
	Write-Host "The host's server at $HostIp is reachable."
} catch {
	Write-Host "Can't reach the host's server at http://${HostIp}:9000 yet."
	Write-Host "Ask the host to start it (scripts/start-server.sh) and to share their machine with you in Tailscale."
}

Write-Host ""
Write-Host "Done. Start playing with: scripts\play.ps1   (or scripts\play.ps1 -Editor to open the Godot editor)"
