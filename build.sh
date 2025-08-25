#!/bin/bash

# Bail out if any command fails
set -e

# Fetch the dir where this bash script is
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

sudo cp "$DIR/server/MPList.lua" "${DIR}/civ5game/Assets/UI/InGame/WorldView/MPList.lua"

# Build the container
docker build -t civ5server "${DIR}/server"
