#!/bin/bash
# Loads the starter data (the "Empty Space" template used by Create New Space, with
# its terrain, environment and server config) from mirror-web-server/database_backup
# into MongoDB. Only runs when there are no space templates yet, and never deletes
# existing data. setup-server.sh calls this; it's safe to rerun.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DUMP="$ROOT/mirror-web-server/database_backup/dump.archive"
MONGO_URI="${MONGO_URI:-mongodb://127.0.0.1:27017}"
COUNT_TEMPLATES='db.getSiblingDB("themirror").spaces.countDocuments({isTMTemplate: true})'

if [ "$(uname)" = "Darwin" ]; then
	# Homebrew's mongodb-community normally pulls these in; install them if not.
	command -v mongosh > /dev/null || brew install mongosh
	command -v mongorestore > /dev/null || brew install mongodb/brew/mongodb-database-tools
	mongo_shell() { mongosh --quiet "$MONGO_URI" --eval "$1"; }
	mongo_restore() { mongorestore --quiet --uri="$MONGO_URI" --archive="$DUMP"; }
else
	# The mongo container ships mongosh and mongorestore.
	DOCKER="$(command -v docker || command -v podman)"
	mongo_shell() { "$DOCKER" exec mirror-mongo mongosh --quiet --eval "$1"; }
	mongo_restore() { "$DOCKER" exec -i mirror-mongo mongorestore --quiet --archive < "$DUMP"; }
fi

# Assigned separately so a MongoDB connection error stops the script.
TEMPLATES="$(mongo_shell "$COUNT_TEMPLATES")"
if [ "$TEMPLATES" != "0" ]; then
	echo "Database already has space templates; skipping seed."
	exit 0
fi

echo "Seeding MongoDB with the starter space template..."
mongo_restore 2>&1 | grep -v "Cross-version dump & restore" || true
echo "Space templates now: $(mongo_shell "$COUNT_TEMPLATES")"
