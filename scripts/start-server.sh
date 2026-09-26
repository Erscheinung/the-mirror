#!/bin/bash
# Starts the self-hosted Mirror web server (port 9000). Run scripts/setup-server.sh once first.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/mirror-web-server"

if [ ! -f .env ] || [ ! -f dist/main.js ]; then
	echo "Run scripts/setup-server.sh first."
	exit 1
fi

source "$ROOT/scripts/start-db.sh"

source "$ROOT/scripts/use-node.sh"
exec node dist/main.js
