# Sourced by the server scripts: puts a Node version that mirror-web-server
# supports (18-22) on PATH. Node 23+ removed APIs its dependencies still use.

for candidate in /opt/homebrew/opt/node@22/bin /usr/local/opt/node@22/bin /usr/lib/node22/bin; do
	if [ -x "$candidate/node" ]; then
		export PATH="$candidate:$PATH"
		break
	fi
done

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2> /dev/null || echo 0)"
if [ "$NODE_MAJOR" -lt 18 ] || [ "$NODE_MAJOR" -gt 22 ]; then
	echo "mirror-web-server needs Node 18-22 (found: $(node -v 2> /dev/null || echo none))."
	echo "  macOS:        brew install node@22"
	echo "  Arch/Omarchy: sudo pacman -S nodejs-lts-jod   (or: mise use -g node@22)"
	echo "  Debian/Ubuntu/Fedora: install Node 22 from https://nodejs.org or with mise/nvm"
	exit 1
fi
