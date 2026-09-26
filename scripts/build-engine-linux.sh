#!/bin/bash
# Builds The Mirror's Godot fork editor for Linux (x86_64) from source.
# Stock Godot cannot run mirror-godot-app: it needs the fork's custom modules
# (the_mirror, jolt, network_synchronizer), and the old prebuilt downloads are gone.
#
# Installs build dependencies on Arch/Omarchy (pacman), Debian/Ubuntu (apt) or
# Fedora (dnf). Output: godot-engine/bin/godot.linuxbsd.editor.x86_64
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if command -v pacman > /dev/null; then
	sudo pacman -S --needed --noconfirm base-devel git python scons pkgconf cmake \
		libxcursor libxinerama libxi libxrandr libxkbcommon wayland mesa glu libglvnd \
		alsa-lib libpulse
elif command -v apt-get > /dev/null; then
	sudo apt-get update
	sudo apt-get install -y build-essential git python3 scons pkg-config cmake \
		libx11-dev libxcursor-dev libxinerama-dev libxi-dev libxrandr-dev libxkbcommon-dev \
		libwayland-dev libgl1-mesa-dev libglu1-mesa-dev libasound2-dev libpulse-dev libudev-dev
elif command -v dnf > /dev/null; then
	sudo dnf install -y gcc-c++ make git python3 scons pkgconfig cmake \
		libX11-devel libXcursor-devel libXinerama-devel libXi-devel libXrandr-devel \
		libxkbcommon-devel wayland-devel mesa-libGL-devel mesa-libGLU-devel \
		alsa-lib-devel pulseaudio-libs-devel libudev-devel
else
	echo "Unknown distro: install Godot's build dependencies yourself, see"
	echo "https://docs.godotengine.org/en/4.3/contributing/development/compiling/compiling_for_linuxbsd.html"
fi

# The submodule URL is SSH; fetch over HTTPS so no GitHub SSH key is needed.
git -c submodule.godot-engine.url=https://github.com/the-mirror-gdp/godot.git \
	submodule update --init --depth 1 godot-engine

cd godot-engine
git submodule update --init --depth 1 \
	modules/network_synchronizer \
	modules/jolt/thirdparty/JoltPhysics \
	modules/jolt/thirdparty/mimalloc

# Godot 4.3's bundled C libraries predate GCC 15's C23 default.
scons platform=linuxbsd target=editor -j"$(nproc)" cflags="-std=gnu17"

echo "Built: $ROOT/godot-engine/bin/godot.linuxbsd.editor.x86_64"
echo "Run it, then import mirror-godot-app/project.godot."
