#!/bin/bash

# Bail out if any command fails
set -e

# Fetch the dir where this bash script is
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Patch MPList.lua for turn and player status tracking
PATCH_ALREADY_APPLIED="Reversed (or previously applied) patch detected!"
set +e
PATCH_RESULTS=$(patch --forward --reject-file=- "${DIR}/civ5game/Assets/UI/InGame/WorldView/MPList.lua" < "${DIR}/server/MPList.lua.patch" 2>&1)
if [ ${?} -eq 1 ]; then
    set -e
    PATCH_RESULTS_SINGLE_LINE=$(echo "${PATCH_RESULTS}" | tr '\n' ' ')
    if [[ ${PATCH_RESULTS_SINGLE_LINE} != *${PATCH_ALREADY_APPLIED}* ]]; then
        echo "${PATCH_RESULTS_SINGLE_LINE}"
        exit 1
    fi
else
    set -e
fi

# Build the container
docker build -t civ5server "${DIR}/server"
