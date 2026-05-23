#!/usr/bin/env bash

# Exit on error, fail if an unset variable is referenced, and fail if a command fails in a pipe.
set -o errexit -o nounset -o pipefail
# Force subshells (function calls) to inherit errexit.
shopt -s inherit_errexit

sleep 30

# Deploy steam client dlls
STEAM_DLLS_ARRAY=("${STEAM_DLLS}")
for dll in "${STEAM_DLLS_ARRAY[@]}"; do
    \cp --force --preserve "/home/${CONTAINER_USERNAME}/.wine/drive_c/Program Files (x86)/Steam/${dll}" /home/"${CONTAINER_USERNAME}"/civ5game
done

# Verify civ5 resolution is set properly
WINDOWRESX=$(echo "${DESKTOP_RESOLUTION}" | cut --delimiter "x" --fields 1)
WINDOWRESY=$(echo "${DESKTOP_RESOLUTION}" | cut --delimiter "x" --fields 2)
sed -i -- "s/WindowResX = .*/WindowResX = ${WINDOWRESX}\r/g" "${CIV_DATA_ROOT}/GraphicsSettingsDX9.ini"
sed -i -- "s/WindowResY = .*/WindowResY = ${WINDOWRESY}\r/g" "${CIV_DATA_ROOT}/GraphicsSettingsDX9.ini"

# Run the autostart script in the background
/usr/local/bin/attempt_autostart.bash &

# Run civ5 in WINE
# Disable errexit to fire the server_down_notifier.bash script if civ5 crashes
set +o errexit
sudo --user="${CONTAINER_USERNAME}" --preserve-env bash -c 'cd /home/"${CONTAINER_USERNAME}"/civ5game && WINEDEBUG=+seh,+warn,+loaddll,+timestamp WINEDLLOVERRIDES="lsteamclient=d;" PROTONPATH=/home/"${CONTAINER_USERNAME}"/proton/GE-Proton umu-run /home/"${CONTAINER_USERNAME}"/civ5game/CivilizationV_Server.exe'
set -o errexit

# If civ fails (the command before has terminated),
# then fire off a notification that it has crashed
/usr/local/bin/server_down_notifier.bash
