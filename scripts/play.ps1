# Launches The Mirror with the Mirror fork of Godot built by the setup scripts.
#
# Usage: scripts\play.ps1            play (the in-game editor is available in spaces)
#        scripts\play.ps1 -Editor    open the project in the Godot editor
#        scripts\play.ps1 -Import    import the project's assets and exit (done by setup)
param([switch]$Editor, [switch]$Import)
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$App = Join-Path $Root "mirror-godot-app"
$Godot = Join-Path $Root "godot-engine\bin\godot.windows.editor.x86_64.exe"
if (-not (Test-Path $Godot)) { throw "The Mirror Godot build is missing. Run scripts\setup-friend.ps1 first." }

if ($Import) {
	& $Godot --headless --import --path $App | Out-Host
} elseif ($Editor) {
	Start-Process $Godot -ArgumentList "--editor", "--path", "`"$App`""
} else {
	# Assets must be imported once before the game can run.
	if (-not (Test-Path (Join-Path $App ".godot\imported"))) { & $Godot --headless --import --path $App | Out-Host }
	Start-Process $Godot -ArgumentList "--path", "`"$App`""
}
