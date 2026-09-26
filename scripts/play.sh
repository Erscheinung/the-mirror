#!/bin/bash
# Launches The Mirror with the Mirror fork of Godot built by the setup scripts.
#
# Usage: scripts/play.sh            play (the in-game editor is available in spaces)
#        scripts/play.sh --editor   open the project in the Godot editor
#        scripts/play.sh --import   import the project's assets and exit (done by setup)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/mirror-godot-app"

if [ "$(uname)" = "Darwin" ]; then
	GODOT="$ROOT/godot-engine/bin/MirrorGodot.app/Contents/MacOS/Godot"
else
	GODOT="$ROOT/godot-engine/bin/godot.linuxbsd.editor.x86_64"
fi
if [ ! -x "$GODOT" ]; then
	echo "The Mirror Godot build is missing. Run scripts/setup-friend.sh (or scripts/setup-host.sh) first."
	exit 1
fi

case "${1:-}" in
	--editor) exec "$GODOT" --editor --path "$APP" ;;
	--import) exec "$GODOT" --headless --import --path "$APP" ;;
	*)
		# Assets must be imported once before the game can run.
		[ -d "$APP/.godot/imported" ] || "$GODOT" --headless --import --path "$APP"
		exec "$GODOT" --path "$APP"
		;;
esac
