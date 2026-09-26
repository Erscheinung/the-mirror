# Sourced by the server scripts: makes sure MongoDB (27017) and Redis (6379) are running,
# leaving alone any that are already up (however they were started).

port_open() { nc -z 127.0.0.1 "$1" > /dev/null 2>&1; }

if [ "$(uname)" = "Darwin" ]; then
	port_open 6379 || brew services start redis
	port_open 27017 || brew services start mongodb/brew/mongodb-community
else
	DOCKER="$(command -v docker || command -v podman)"
	port_open 27017 || "$DOCKER" start mirror-mongo
	port_open 6379 || "$DOCKER" start mirror-redis
fi

for port in 27017 6379; do
	for _ in $(seq 1 20); do port_open $port && break; sleep 0.5; done
	port_open $port || { echo "Nothing is listening on port $port (MongoDB 27017 / Redis 6379)."; exit 1; }
done
