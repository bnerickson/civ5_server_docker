#!/usr/bin/env bash

# Exit on error, fail if an unset variable is referenced, and fail if a command fails in a pipe.
set -o errexit -o nounset -o pipefail
# Force subshells (function calls) to inherit errexit.
shopt -s inherit_errexit

# Fetch the dir where this bash script is
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Source the config file
CONFIG_FILE="${DIR}/build.conf"
source "${CONFIG_FILE}"

# Set default values if unset in config file
CONTAINER_USERNAME=${CONTAINER_USERNAME:-""}
CONTAINER_GROUP=${CONTAINER_GROUP:-""}
CONTAINER_NAME=${CONTAINER_NAME:-"civ5"}
SCRIPT_TIMEZONE=${SCRIPT_TIMEZONE:-"America/Los_Angeles"}
GPU_BUSID=${GPU_BUSID:-"ff:ff.ff"}
CPU_LIMIT=${CPU_LIMIT:-"100"}
VNC_PORT=${VNC_PORT:-"5900"}
CIV5_FWD_PORT=${CIV5_FWD_PORT:-"27016"}
DISPLAY=${DISPLAY:-":99"}
STEAM_INSTALL_SLEEP_TIMER=${STEAM_INSTALL_SLEEP_TIMER:-"120"}
DXVK_FRAME_RATE=${DXVK_FRAME_RATE:-"2"}
GE_PROTON_VERSION=${GE_PROTON_VERSION:-"latest"}
NTFY_TOPIC=${NTFY_TOPIC:-""}
DISCORD_WEBHOOK_ID=${DISCORD_WEBHOOK_ID:-""}
DISCORD_WEBHOOK_TOKEN=${DISCORD_WEBHOOK_TOKEN:-""}

# Verify container username and group are valid
CONTAINER_UID=$(id --user "${CONTAINER_USERNAME}")
if [ "${CONTAINER_USERNAME}" = "root" ] || [ "${CONTAINER_USERNAME}" = "" ]; then
    echo "Container must be run as a non-root user, umu-launcher only supports running as a non-root user, exiting"
    exit 1
fi
CONTAINER_GID=$(getent group "${CONTAINER_GROUP}" | cut --delimiter ":" --fields 3)
if [ "${CONTAINER_GROUP}" = "root" ] || [ "${CONTAINER_GROUP}" = "" ]; then
    echo "Container must be run as a non-root group, umu-launcher only supports running as a non-root group, exiting"
    exit 1
fi

# Apply our custom lua patches
PATCH_ALREADY_APPLIED="Reversed (or previously applied) patch detected!"
declare -A PATCHES=( [MPList.lua.patch]="Assets/UI/InGame/WorldView/MPList.lua" [StagingRoom.lua.patch]="Assets/UI/FrontEnd/Multiplayer/StagingRoom.lua" )
for patch in "${!PATCHES[@]}"; do
    set +e
    PATCH_RESULTS=$(patch --forward --reject-file=- "${DIR}/civ5game/${PATCHES[${patch}]}" < "${DIR}/server/${patch}" 2>&1)
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
done

# Update the ntfy and discord files
echo "${NTFY_TOPIC}" > "${DIR}/server/ntfy_topic.txt"
sed --in-place '/^$/d' "${DIR}/server/ntfy_topic.txt"
echo "${DISCORD_WEBHOOK_ID}" > "${DIR}/server/discord_webhook_id.txt"
sed --in-place '/^$/d' "${DIR}/server/discord_webhook_id.txt"
echo "${DISCORD_WEBHOOK_TOKEN}" > "${DIR}/server/discord_webhook_token.txt"
sed --in-place '/^$/d' "${DIR}/server/discord_webhook_token.txt"
chmod 600 "${DIR}/server/discord_webhook_token.txt"

# Verify GPU BusID value and convert it to decimal
busid_re="^[0-9a-fA-F]{1,2}:[0-9a-fA-F]{1,2}\.[0-9a-fA-F]{1,2}$"
if ! [[ ${GPU_BUSID} =~ ${busid_re} ]]; then
    echo "GPU_BUSID value ${GPU_BUSID} is invalid, exiting"
    exit 1
fi
gpu_bus_num=$((16#$(echo "${GPU_BUSID}" | cut --delimiter ":" --fields 1)))
gpu_device_num=$((16#$(echo "${GPU_BUSID}" | cut --delimiter ":" --fields 2 | cut --delimiter "." --fields 1)))
gpu_function_num=$((16#$(echo "${GPU_BUSID}" | cut --delimiter "." --fields 2)))
GPU_BUSID_DECIMAL="${gpu_bus_num}:${gpu_device_num}:${gpu_function_num}"

# Get GPU_DEVICES value
intel_gpu_check=$(lspci | (grep --extended --ignore-case "${GPU_BUSID} .*intel" || true))
amd_gpu_check=$(lspci | (grep --extended --ignore-case "${GPU_BUSID} .*amd" || true))
GPU_VENDOR="dummy"
DXVK_FILTER_VARIABLE="llvmpipe"
GPU_DEVICES=""
if [ "${intel_gpu_check}" != "" ]; then
    DXVK_FILTER_VARIABLE=""
    GPU_VENDOR="intel"
    GPU_DEVICES="\n    devices:\n      - /dev/dri"
fi
if [ "${amd_gpu_check}" != "" ]; then
    DXVK_FILTER_VARIABLE=""
    GPU_VENDOR="amd"
    GPU_DEVICES="\n    devices:\n      - /dev/kfd\n      - /dev/dri"
fi

# Create docker compose file
(sed --expression="s|@CONTAINER_USERNAME@|${CONTAINER_USERNAME}|g" --expression="s|@CONTAINER_UID@|${CONTAINER_UID}|g" --expression="s|@CONTAINER_GID@|${CONTAINER_GID}|g" --expression="s|@CIVDIR@|${DIR}|g" --expression="s|@TIMEZONE@|${SCRIPT_TIMEZONE}|g" --expression="s|@GPU_BUSID@|${GPU_BUSID_DECIMAL}|g" --expression="s|@GPU_DEVICES@|${GPU_DEVICES}|g" --expression="s|@GPU_VENDOR@|${GPU_VENDOR}|g" --expression="s|@CPU_LIMIT@|${CPU_LIMIT}|g" --expression="s|@STEAM_INSTALL_SLEEP_TIMER@|${STEAM_INSTALL_SLEEP_TIMER}|g" --expression="s|@DXVK_FRAME_RATE@|${DXVK_FRAME_RATE}|g" --expression="s|@GE_PROTON_VERSION@|${GE_PROTON_VERSION}|g" --expression="s|@VNC_PORT@|${VNC_PORT}|g" --expression="s|@CIV5_FWD_PORT@|${CIV5_FWD_PORT}|g" --expression="s|@CONTAINER_NAME@|${CONTAINER_NAME}|g" --expression="s|@DISPLAY@|${DISPLAY}|g" --expression="s|@DXVK_FILTER_VARIABLE@|${DXVK_FILTER_VARIABLE}|g" < "${DIR}/docker-compose.yml.templ" < "${DIR}/docker-compose.yml.templ") > "${DIR}/server/docker-compose.yml"
