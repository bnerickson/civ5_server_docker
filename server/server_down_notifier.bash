#!/usr/bin/env bash

# Exit on error, fail if an unset variable is referenced, and fail if a command fails in a pipe.
set -o errexit -o nounset -o pipefail
# Force subshells (function calls) to inherit errexit.
shopt -s inherit_errexit

DISCORD_WEBHOOK_ID=$(cat ${DISCORD_WEBHOOK_ID_FILE})
DISCORD_WEBHOOK_TOKEN=$(cat ${DISCORD_WEBHOOK_TOKEN_FILE})
JSON_FILE="${CIV_DATA_ROOT}/disconnected_turn_status.json"
NTFY_TOPIC=$(cat ${NTFY_TOPIC_FILE})

set +o errexit
CIV5_PID=$(pgrep --full --exact CivilizationV_Server.exe)
set -o errexit

if [ "${CIV5_PID}" != "" ]; then
    exit 0
fi

# We use this as evidence the server crashed for
# notification purposes.
python3 /usr/local/bin/json_file_helper.py --config "${JSON_FILE}" set --parameter crash --value True

notification_string="$(date +"%Y%m%d-%H%M%S") THE SYSTEM IS DOWN: Civilization V has crashed.  Attempting to restart automatically (ETA 5 minutes)..."
printf "%s\n" "${notification_string}"

if [ "${NTFY_TOPIC}" != "" ]; then
    while : ; do
        set +o errexit
        curl -d "${notification_string}" ntfy.sh/${NTFY_TOPIC}
        if [ "${?}" = 0 ]; then
            # Successfully notified
            set -o errexit
            break
        fi
        set -o errexit
        sleep 60
    done
fi

if [ "${DISCORD_WEBHOOK_ID}" != "" ] && [ "${DISCORD_WEBHOOK_TOKEN}" != "" ]; then
    while : ; do
        set +o errexit
        curl -X POST -H "Content-Type: application/json" -d '{"content": "'"${notification_string}"'"}' "https://discord.com/api/webhooks/${DISCORD_WEBHOOK_ID}/${DISCORD_WEBHOOK_TOKEN}"
        if [ "${?}" = 0 ]; then
            # Successfully notified
            set -o errexit
            break
        fi
        set -o errexit
        sleep 60
    done
fi
