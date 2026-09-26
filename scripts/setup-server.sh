#!/bin/bash
# One-time setup of the self-hosted Mirror backend on the host machine (macOS or Linux):
# MongoDB + Redis, Node 22, mirror-web-server dependencies/build, and a .env
# configured for Tailscale. No Firebase or cloud accounts are needed.
#
# Usage: scripts/setup-server.sh [host-ip]   (defaults to this machine's Tailscale IPv4)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVER="$ROOT/mirror-web-server"

TAILSCALE="$(command -v tailscale || echo /Applications/Tailscale.app/Contents/MacOS/Tailscale)"
HOST_IP="${1:-$("$TAILSCALE" ip -4 2> /dev/null | head -1 || true)}"
if [ -z "$HOST_IP" ]; then
	echo "Could not get a Tailscale IP. Run 'tailscale up' (or pass the IP to use as the first argument)."
	exit 1
fi

# --- MongoDB, Redis and Node 22 -------------------------------------------------
if [ "$(uname)" = "Darwin" ]; then
	brew tap mongodb/brew
	# Newer Homebrew only loads formulae from taps you trust (this is MongoDB's official tap).
	if brew trust --help > /dev/null 2>&1; then brew trust mongodb/brew; fi
	brew install node@22 redis mongodb/brew/mongodb-community
	source "$ROOT/scripts/start-db.sh"
else
	# MongoDB isn't packaged by most distros (on Arch it's AUR-only), so run both in containers.
	if command -v docker > /dev/null; then
		DOCKER=docker
	elif command -v podman > /dev/null; then
		DOCKER=podman
	else
		echo "Install docker or podman first (Arch/Omarchy: sudo pacman -S docker && sudo systemctl enable --now docker)."
		exit 1
	fi
	$DOCKER start mirror-mongo 2> /dev/null ||
		$DOCKER run -d --name mirror-mongo --restart unless-stopped -p 127.0.0.1:27017:27017 -v mirror-mongo:/data/db docker.io/library/mongo:7
	$DOCKER start mirror-redis 2> /dev/null ||
		$DOCKER run -d --name mirror-redis --restart unless-stopped -p 127.0.0.1:6379:6379 docker.io/library/redis:7
fi

source "$ROOT/scripts/use-node.sh"

# --- .env ---------------------------------------------------------------------
if [ ! -f "$SERVER/.env" ]; then
	cat > "$SERVER/.env" << EOF
# Self-hosted Mirror server (Tailscale). Keep this file private; it is gitignored.
NODE_ENV=development
PORT=9000

# Self-hosted login instead of Firebase (users are stored in MongoDB)
AUTH_PROVIDER=local
LOCAL_AUTH_SECRET=$(openssl rand -hex 32)

MONGODB_URL=mongodb://127.0.0.1:27017/themirror
REDISHOST=127.0.0.1
REDISPORT=6379

# Admin secrets for internal tools (keep private)
WSS_SECRET=$(openssl rand -hex 24)
ADMIN_UTIL_SECRET=$(openssl rand -hex 24)

# Uploaded assets are stored on this machine and served to everyone over Tailscale
ASSET_STORAGE_DRIVER=LOCAL
ASSET_STORAGE_URL=http://$HOST_IP:9000/assets-storage/

DISABLE_EMAIL=true
EOF
	echo "Wrote $SERVER/.env"
else
	echo "Keeping existing $SERVER/.env"
fi

# --- Build the web server -----------------------------------------------------
cd "$SERVER"
npx --yes yarn@1.22.22 install --frozen-lockfile --ignore-engines
npx --yes yarn@1.22.22 build

# --- Point the host's game at this server --------------------------------------
"$ROOT/scripts/set-mirror-host.sh" "$HOST_IP" host

echo
echo "Setup done. Start the server with: scripts/start-server.sh"
echo "Friends run: ./setup-mac.sh or ./setup-linux.sh $HOST_IP  (Windows: setup-win.ps1 $HOST_IP)"
