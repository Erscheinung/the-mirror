# Builds The Mirror's Godot fork editor for Windows (x86_64) from source.
# Stock Godot cannot run mirror-godot-app: it needs the fork's custom modules
# (the_mirror, jolt, network_synchronizer), and the old prebuilt downloads are gone.
#
# Installs anything missing with winget: Git, Python, CMake, Ninja and the
# Visual Studio 2022 C++ Build Tools (a large download the first time).
# Run from the repo root:  powershell -ExecutionPolicy Bypass -File scripts\build-engine-windows.ps1
# Output: godot-engine\bin\godot.windows.editor.x86_64.exe
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Update-Path {
	$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

function Install-IfMissing([string]$Command, [string]$WingetId) {
	if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
		Write-Host "Installing $WingetId..."
		winget install --id $WingetId -e --accept-source-agreements --accept-package-agreements
		Update-Path
	}
}

Install-IfMissing git Git.Git
# "python" may be the Microsoft Store stub, which exists but doesn't run.
python --version 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
	winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements
	Update-Path
}
Install-IfMissing cmake Kitware.CMake
Install-IfMissing ninja Ninja-build.Ninja

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$hasVcTools = (Test-Path $vswhere) -and (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)
if (-not $hasVcTools) {
	Write-Host "Installing Visual Studio 2022 Build Tools (C++)... this takes a while."
	winget install --id Microsoft.VisualStudio.2022.BuildTools -e --accept-source-agreements --accept-package-agreements `
		--override "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --passive --wait"
}

# The Jolt module builds with CMake + Ninja, which need the MSVC environment.
if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
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
