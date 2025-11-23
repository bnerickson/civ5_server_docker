#!/usr/bin/env bash
# The coordinates in the mousemove commands are based on
# a fixed desktop resolution of 1600x900.  If a custom
# desktop resolution is set, ALL of the coordinates below
# need to be updated.

set -o errexit -o nounset -o pipefail


DISCORD_WEBHOOK_ID=$(cat ${DISCORD_WEBHOOK_ID_FILE})
DISCORD_WEBHOOK_TOKEN=$(cat ${DISCORD_WEBHOOK_TOKEN_FILE})
NTFY_TOPIC=$(cat ${NTFY_TOPIC_FILE})
SQLITE_DB="GameLaunch-1.db"
# "800 655"   - Click on the "Click to Continue" button
# "725 865"   - Click on the "Load Game" button
# "1215 240"  - Click on the "autosaves" checkbox
# "1000 315"  - Click on the latest autosave
# "1105 750"  - Click on the "Load Game" button
# "925 250"   - Click on the observer ready checkbox
# "1115 860"  - Click on the "Launch Game" button
MOUSE_MOVE_ARRAY=("800 655" "725 865" "1215 240" "1000 315" "1105 750" "925 250" "1115 860")


function perform_mouse_commands {
    # Wait for civ5 to load
    sleep 60

    window_id=$(xdotool search --onlyvisible --name "Sid*")

    for mouse_coordinates in "${MOUSE_MOVE_ARRAY[@]}"; do
        xdotool windowfocus --sync ${window_id}
        xdotool mousemove ${mouse_coordinates}
        xdotool click 1
        sleep 10
    done

    # Wait for the server to start
    sleep 50
}


function main {
    civ5autosaves=$(find "${CIV_DATA_ROOT}/Saves/multi/auto/" -maxdepth 1 -name "*.Civ5Save" -type f)
    notification_string="There are no Civilization V auto-saves to reload: An administrator must login to start the server."

    if [ "${civ5autosaves}" != "" ]; then
        perform_mouse_commands

        if [ -f "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}" ]; then
            # We launched the game successfully
            notification_string="Civilization V has successfully loaded the most recent auto-save: The game is waiting for ALL players to take their turns."
            rm --force "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}"
        else
            # We failed to launch the game
            notification_string="Civilization V has failed to load the most recent auto-save: An administrator must login to start the server."
        fi
    fi

    if [ "${NTFY_TOPIC}" != "" ]; then
        # notifications are best effort. We
        # don't want to crash this process if
        # a notification failed to process.
        set +o errexit
        curl -d "${notification_string}" ntfy.sh/${NTFY_TOPIC}
        set -o errexit
    fi
    if [ "${DISCORD_WEBHOOK_ID}" != "" ] && [ "${DISCORD_WEBHOOK_TOKEN}" != "" ]; then
        # notifications are best effort. We
        # don't want to crash this process if
        # a notification failed to process.
        set +o errexit
        curl -X POST -H "Content-Type: application/json" -d '{"content": "'"${notification_string}"'"}' "https://discord.com/api/webhooks/${DISCORD_WEBHOOK_ID}/${DISCORD_WEBHOOK_TOKEN}"
        set -o errexit
    fi
}


main
