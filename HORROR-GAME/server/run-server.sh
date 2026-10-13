#!/usr/bin/env bash
# Starts the headless co-op server on Linux or macOS.
# Usage: server/run-server.sh [--port 7777] [--max-players 4] [--public-host 203.0.113.5]
# Set GODOT to the Godot 4.7 binary when it is not on the PATH. On macOS this is usually
# /Applications/Godot.app/Contents/MacOS/Godot
set -eu

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
godot="${GODOT:-godot}"

if ! command -v "$godot" >/dev/null 2>&1; then
	echo "Godot was not found. Install Godot 4.7 or set GODOT to its path." >&2
	exit 1
fi

exec "$godot" --headless --path "$project_dir" res://scenes/dedicated_server.tscn -- "$@"
