#!/bin/bash
# One command for the host (macOS / Linux): builds the Mirror fork of Godot,
# installs and configures the self-hosted server (MongoDB, Redis, Node 22,
# mirror-web-server) for this machine's Tailscale IP, and imports the project.
# Safe to rerun; steps that are already done are quick.
#
# Usage: scripts/setup-host.sh [host-tailscale-ip]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ "$(uname)" = "Darwin" ]; then
	"$ROOT/scripts/build-engine-mac.sh"
else
	"$ROOT/scripts/build-engine-linux.sh"
fi

"$ROOT/scripts/setup-server.sh" "$@"
# The first import can end early when Godot restarts itself, so allow a second pass.
"$ROOT/scripts/play.sh" --import || "$ROOT/scripts/play.sh" --import

echo
echo "Next: scripts/start-server.sh (keep it running), then scripts/play.sh"
