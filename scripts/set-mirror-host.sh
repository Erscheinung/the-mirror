#!/bin/bash
# Points the game at the machine running the Mirror server and picks your role.
#
# Usage: scripts/set-mirror-host.sh <host-tailscale-ip> <host|join>
#   host: you run the web server and open spaces (a game server starts on your machine)
#   join: you connect to the host's server
set -euo pipefail

if [ $# -ne 2 ] || { [ "$2" != "host" ] && [ "$2" != "join" ]; }; then
	echo "Usage: $0 <host-tailscale-ip> <host|join>"
	exit 1
fi
HOST_IP="$1"
ROLE="$2"

APP="$(cd "$(dirname "$0")/.." && pwd)/mirror-godot-app"
CONFIGS="$APP/addons/mirror_internal/env_configs"

# Replace the IPv4 address in both presets, then activate the chosen one.
for preset in "$CONFIGS/tailscale-host.cfg" "$CONFIGS/tailscale-join.cfg"; do
	sed -E -i.bak "s#(http://|ws://|zone_server_host=\")[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+#\1$HOST_IP#g" "$preset"
	rm -f "$preset.bak"
done
cp "$CONFIGS/tailscale-$ROLE.cfg" "$APP/override.cfg"

echo "Game set to '$ROLE' with the Mirror server at $HOST_IP."
