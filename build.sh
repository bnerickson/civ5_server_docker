#!/bin/bash

# Bail out if any command fails
set -e

# Get the timezone for the civ5.env
echo "Getting the system timezone"
SCRIPT_TIMEZONE=$(timedatectl show --property=Timezone --value)

# Fetch the dir where this bash script is
echo "Getting the current working dir"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Apply our custom lua patches
PATCH_ALREADY_APPLIED="Reversed (or previously applied) patch detected!"
declare -A PATCHES=( [MPList.lua.patch]="Assets/UI/InGame/WorldView/MPList.lua" [StagingRoom.lua.patch]="Assets/UI/FrontEnd/Multiplayer/StagingRoom.lua" )

for patch in "${!PATCHES[@]}"; do
    set +e
    echo "Attempting to apply the ${patch} patch to ${DIR}/civ5game/${PATCHES[${patch}]}"
    PATCH_RESULTS=$(patch --forward --reject-file=- "${DIR}/civ5game/${PATCHES[${patch}]}" < "${DIR}/server/${patch}" 2>&1)
    if [ ${?} -eq 1 ]; then
        set -e
        PATCH_RESULTS_SINGLE_LINE=$(echo "${PATCH_RESULTS}" | tr '\n' ' ')
        if [[ ${PATCH_RESULTS_SINGLE_LINE} != *${PATCH_ALREADY_APPLIED}* ]]; then
            echo "${PATCH_RESULTS_SINGLE_LINE}"
            exit 1
        fi
        echo "Patch ${DIR}/server/${patch} already applied to ${DIR}/civ5game/${PATCHES[${patch}]}, continuing without modification"
    else
        set -e
    fi
done

# Create the secrets files that are empty by default
if [ ! -f "${DIR}/server/ntfy_topic.txt" ]; then
    echo "Creating empty credential file ${DIR}/server/ntfy_topic.txt"
    touch "${DIR}/server/ntfy_topic.txt"
    chmod 600 "${DIR}/server/ntfy_topic.txt"
else
    echo "Credential file ${DIR}/server/ntfy_topic.txt already exists, continuing without modification"
fi
if [ ! -f "${DIR}/server/discord_webhook_id.txt" ]; then
    echo "Creating empty credential file ${DIR}/server/discord_webhook_id.txt"
    touch "${DIR}/server/discord_webhook_id.txt"
    chmod 600 "${DIR}/server/discord_webhook_id.txt"
else
    echo "Credential file ${DIR}/server/discord_webhook_id.txt already exists, continuing without modification"
fi
if [ ! -f "${DIR}/server/discord_webhook_token.txt" ]; then
    echo "Creating empty credential file ${DIR}/server/discord_webhook_token.txt"
    touch "${DIR}/server/discord_webhook_token.txt"
    chmod 600 "${DIR}/server/discord_webhook_token.txt"
else
    echo "Credential file ${DIR}/server/discord_webhook_token.txt already exists, continuing without modification"
fi

# Create default docker compose file
if [ ! -f "${DIR}/server/docker-compose.yml" ]; then
    echo "Creating default yml file ${DIR}/server/docker-compose.yml"
    (sed --expression="s|@CIVDIR@|${DIR}|" --expression="s|@TIMEZONE@|${SCRIPT_TIMEZONE}|" < "${DIR}/docker-compose.yml.templ") > "${DIR}/server/docker-compose.yml"
else
    echo "Docker compose yml file ${DIR}/server/docker-compose.yml already exists, continuing without modification"
fi
