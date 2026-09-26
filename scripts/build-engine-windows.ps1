# Builds The Mirror's Godot fork editor for Windows (x86_64) from source.
# Stock Godot cannot run mirror-godot-app: it needs the fork's custom modules
# (the_mirror, jolt, network_synchronizer), and the old prebuilt downloads are gone.
#
# Requirements (install once):
#   winget install Git.Git Python.Python.3.12 Kitware.CMake Ninja-build.Ninja
#   winget install Microsoft.VisualStudio.2022.BuildTools --override "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --passive"
# Run from the repo root:  powershell -ExecutionPolicy Bypass -File scripts\build-engine-windows.ps1
# Output: godot-engine\bin\godot.windows.editor.x86_64.exe
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

# The Jolt module builds with CMake + Ninja, which need the MSVC environment.
if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
	$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
	if (-not (Test-Path $vswhere)) { throw "Visual Studio Build Tools not found (see requirements at the top of this script)." }
	$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
	if (-not $vsPath) { throw "Visual Studio is missing the C++ build tools workload." }
	Import-Module (Join-Path $vsPath "Common7\Tools\Microsoft.VisualStudio.DevShell.dll")
	Enter-VsDevShell -VsInstallPath $vsPath -SkipAutomaticLocation -DevCmdArguments "-arch=x64 -host_arch=x64"
}

# The submodule URL is SSH; fetch over HTTPS so no GitHub SSH key is needed.
git -c submodule.godot-engine.url=https://github.com/the-mirror-gdp/godot.git submodule update --init --depth 1 godot-engine
if ($LASTEXITCODE -ne 0) { throw "git submodule update failed" }

Set-Location godot-engine
git submodule update --init --depth 1 modules/network_synchronizer modules/jolt/thirdparty/JoltPhysics modules/jolt/thirdparty/mimalloc
if ($LASTEXITCODE -ne 0) { throw "git submodule update failed" }

python -m pip install --user scons
python -m SCons platform=windows target=editor -j $env:NUMBER_OF_PROCESSORS
if ($LASTEXITCODE -ne 0) { throw "Engine build failed" }

Write-Host "Built: $Root\godot-engine\bin\godot.windows.editor.x86_64.exe"
Write-Host "Run it, then import mirror-godot-app\project.godot."
