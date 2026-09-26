#!/bin/bash
# Friends: installs everything needed, builds the Mirror fork of Godot and joins the host.
# (The host runs scripts/setup-host.sh instead.)
"$(dirname "$0")/scripts/setup-friend.sh" "$@"
