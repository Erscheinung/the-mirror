#!/bin/bash
# Builds The Mirror's Godot fork editor for macOS (Apple Silicon) from source.
# The precompiled engine downloads are no longer hosted, and stock Godot cannot
# run mirror-godot-app because it relies on the fork's custom modules
# (the_mirror, jolt, network_synchronizer).
#
# Requirements: Xcode command line tools, python3, git.
# Output: godot-engine/bin/MirrorGodot.app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# The submodule URL is SSH; fetch over HTTPS so no GitHub SSH key is needed.
git -c submodule.godot-engine.url=https://github.com/the-mirror-gdp/godot.git \
	submodule update --init --depth 1 godot-engine

cd godot-engine
git submodule update --init --depth 1 \
	modules/network_synchronizer \
	modules/jolt/thirdparty/JoltPhysics \
	modules/jolt/thirdparty/mimalloc

python3 -m SCons --version > /dev/null 2>&1 || python3 -m pip install --user scons

# Godot 4.3 on macOS links MoltenVK statically (Vulkan -> Metal).
MVK_DIR="$ROOT/.engine-deps/MoltenVK"
MVK_XCFRAMEWORK="$MVK_DIR/MoltenVK/MoltenVK/static/MoltenVK.xcframework"
if [ ! -f "$MVK_XCFRAMEWORK/macos-arm64_x86_64/libMoltenVK.a" ]; then
	mkdir -p "$MVK_DIR"
	curl -fL -o "$MVK_DIR/MoltenVK-macos.tar" \
		https://github.com/KhronosGroup/MoltenVK/releases/download/v1.4.0/MoltenVK-macos.tar
	tar xf "$MVK_DIR/MoltenVK-macos.tar" -C "$MVK_DIR"
	rm "$MVK_DIR/MoltenVK-macos.tar"
fi

python3 -m SCons platform=macos arch=arm64 target=editor -j"$(sysctl -n hw.ncpu)" \
	vulkan_sdk_path="$MVK_XCFRAMEWORK"

rm -rf bin/MirrorGodot.app
cp -R misc/dist/macos_tools.app bin/MirrorGodot.app
mkdir -p bin/MirrorGodot.app/Contents/MacOS
cp bin/godot.macos.editor.arm64 bin/MirrorGodot.app/Contents/MacOS/Godot
chmod +x bin/MirrorGodot.app/Contents/MacOS/Godot
codesign --force --deep -s - bin/MirrorGodot.app

echo "Built: $ROOT/godot-engine/bin/MirrorGodot.app"
echo "Open it, then import mirror-godot-app/project.godot."
