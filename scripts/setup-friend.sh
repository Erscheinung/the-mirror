#!/bin/bash
# One command for friends (macOS / Linux): installs Tailscale and the build tools
# if missing, builds the Mirror fork of Godot, points the game at the host and
# imports the project. Safe to rerun; steps that are already done are quick.
#
# Usage: scripts/setup-friend.sh [host-tailscale-ip]
#   Defaults to the host IP committed in the tailscale-join preset.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JOIN_PRESET="$ROOT/mirror-godot-app/addons/mirror_internal/env_configs/tailscale-join.cfg"
HOST_IP="${1:-$(sed -nE 's/^zone_server_host="([0-9.]+)"/\1/p' "$JOIN_PRESET")}"

# --- Tailscale ----------------------------------------------------------------
tailscale_cli() {
	if command -v tailscale > /dev/null; then
		tailscale "$@"
	elif [ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then
		/Applications/Tailscale.app/Contents/MacOS/Tailscale "$@"
	else
		return 127
	fi
}

if [ "$(uname)" = "Darwin" ]; then
	if [ ! -d /Applications/Tailscale.app ] && ! command -v tailscale > /dev/null; then
		command -v brew > /dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		eval "$(/opt/homebrew/bin/brew shellenv 2> /dev/null || /usr/local/bin/brew shellenv)"
		brew install --cask tailscale-app
		open -a Tailscale
	fi
else
	if ! command -v tailscale > /dev/null; then
		if command -v pacman > /dev/null; then
			sudo pacman -S --needed --noconfirm tailscale
		else
			curl -fsSL https://tailscale.com/install.sh | sh
		fi
		sudo systemctl enable --now tailscaled
	fi
fi

if ! tailscale_cli ip -4 > /dev/null 2>&1; then
	if [ "$(uname)" = "Darwin" ]; then
		open -a Tailscale
		echo "Log in to Tailscale in the menu bar app, then run this script again."
		exit 1
	fi
	sudo tailscale up
fi

# --- Engine -------------------------------------------------------------------
if [ "$(uname)" = "Darwin" ]; then
	"$ROOT/scripts/build-engine-mac.sh"
else
	"$ROOT/scripts/build-engine-linux.sh"
fi

# --- Game config + first import ----------------------------------------------
"$ROOT/scripts/set-mirror-host.sh" "$HOST_IP" join
# The first import can end early when Godot restarts itself, so allow a second pass.
"$ROOT/scripts/play.sh" --import || "$ROOT/scripts/play.sh" --import

if curl -s -m 5 -o /dev/null "http://$HOST_IP:9000/"; then
	echo "The host's server at $HOST_IP is reachable."
else
	echo "Can't reach the host's server at http://$HOST_IP:9000 yet."
	echo "Ask the host to start it (scripts/start-server.sh) and to share their machine with you in Tailscale."
fi

echo
echo "Done. Start playing with: scripts/play.sh   (or scripts/play.sh --editor to open the Godot editor)"
