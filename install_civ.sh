#!/usr/bin/env bash

# Exit on error, fail if an unset variable is referenced, and fail if a command fails in a pipe.
set -o errexit -o nounset -o pipefail
# Force subshells (function calls) to inherit errexit.
shopt -s inherit_errexit

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Check that a username/password was supplied
if [ "${#}" -ne 2 ]; then
    printf "Usage: ${0} <steam_username> <steam_password>\n"
    exit 1
fi

if [ "$(id --user)" -eq 0 ]; then
    printf "This script must be executed as a non-root user\n"
    exit 1
fi

mkdir "${SCRIPT_DIR}"/{temp,steam-app}

printf ":: Installing Civ 5 and Civ 5 SDK\n"

docker run \
    --rm \
    -e PUID=$(id -u) -e PGID=$(id -g) \
    -v "${SCRIPT_DIR}/steam-app:/home/steam/.local/share/Steam" \
    -v "${SCRIPT_DIR}:/data" \
    gameservermanagers/steamcmd:latest \
    +@sSteamCmdForcePlatformType windows \
    +login "${1}" "${2}" \
    +force_install_dir /data/civ5game \
    +app_update 8930 \
    +force_install_dir /data/temp \
    +app_update 16830 \
    +quit

printf ":: Moving dedicated server files to the Civ 5 install\n"

mv "${SCRIPT_DIR}/temp/Dedicated Server/"* "${SCRIPT_DIR}"/civ5game/

printf ":: Cleaning up SDK install and SteamCMD Docker container\n"

rm --recursive --force "${SCRIPT_DIR}"/temp/
rm --recursive --force "${SCRIPT_DIR}"/steam-app/

docker image rm gameservermanagers/steamcmd:latest
