#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Import our env variables for the cron job
source /home/${CONTAINER_USERNAME}/civ5.env

DISCORD_WEBHOOK_ID=$(cat "${DISCORD_WEBHOOK_ID_FILE}")
DISCORD_WEBHOOK_TOKEN=$(cat "${DISCORD_WEBHOOK_TOKEN_FILE}")
JSON_FILE="${CIV_DATA_ROOT}/disconnected_turn_status.json"
MAXIMUM_LOOP_COUNT=12
NTFY_TOPIC=$(cat "${NTFY_TOPIC_FILE}")
SQLITE_DB="DynamicTurnStatus-1.db"

printf "Verifying %s file exists and is non-empty...\n" "${SQLITE_DB}"
# Exit if the db does not exist or is empty.
if [ ! -f "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}" ]; then
    printf "The SQLite DB %s does not exist.  Exiting...\n" "${SQLITE_DB}"
    exit 0
fi
if [ ! -s "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}" ]; then
    printf "The SQLite DB %s is empty.  Exiting...\n" "${SQLITE_DB}"
    exit 0
fi
printf "%s file exists and is non-empty.\n" "${SQLITE_DB}"

# Get the saved JSON file's values
json_file_params=""
old_crash_str="False"
if [ -f "${JSON_FILE}" ]; then
    json_file_params=$(python3 /usr/local/bin/json_file_helper.py --config "${JSON_FILE}" print --parameters crash)
fi
while IFS= read -r line; do
    if [[ "${line}" =~ ^crash:.* ]]; then
        old_crash_str=$(echo "${line}" | cut --delimiter ':' --fields 2-)
    fi
done <<< "${json_file_params}"

if [ "${old_crash_str}" == "True" ]; then
    printf "The Civilization V server crashed and has not yet recovered.  Exiting...\n"
    exit 0
fi

cached_player_str=""
cached_turn_num=""
loop_counter=1
player_str=""
turn_num=""

while : ; do
    if (( loop_counter > MAXIMUM_LOOP_COUNT )); then
        # Exit (give up) if we have looped 12 times (1 minute).
        printf "Unable to extract TurnNum and PlayersWhoNeedToTakeTheirTurn values found in %s.\nTurnNum: %s\nPlayersWhoNeedToTakeTheirTurn: %s\nNot sending notification and exiting...\n" "${SQLITE_DB}" "${turn_num}" "${player_str}"
        exit 1
    fi

    # Query the sqlite DB for the values we need.
    # We disable errexit because we don't want to
    # bomb the script if the query fails and will
    # retry instead.
    set +o errexit
    sqlite_query=$(sqlite3 "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}" ".mode csv" "SELECT * FROM SimpleValues;" | sed $'s/\x1f/, /g')
    sql_query_exit_status="${?}"
    set -o errexit

    if [ "${sql_query_exit_status}" -ne 0 ]; then
        # Loop if the sql query failed.
        sleep 5
        loop_counter=$((loop_counter+1))
        continue
    fi

    # Replace Unit Separator character wtih a comma+space.
    sqlite_query_formatted=$(echo "${sqlite_query}" | sed $'s/\x1f/, /g')
    while IFS= read -r line; do
        if [[ "${line}" =~ ^TurnNum,.* ]]; then
            # Remove DOS carriage return with sed statement
            turn_num=$(echo "${line}" | cut --delimiter ',' --fields 2- | sed 's/\r$//')
        elif [[ "${line}" =~ ^PlayersWhoNeedToTakeTheirTurn,.* ]]; then
            # Remove the leading and trailing quotes and commas
            # when there are multiple players.  The final sed
            # removes DOS carriage returns.
            player_str=$(echo "${line}" | cut --delimiter ',' --fields 2- | sed 's/^"//g' | sed 's/, ".$//g' | sed 's/\r$//')
        fi
    done <<< "${sqlite_query_formatted}"

    if [ "${player_str}" != "" ] && [ "${turn_num}" != "" ]; then
        # This is a sanity check to verify that the data in the SQLite DB
        # was updated successfully.  We check at least twice, and if the
        # values are the same for both checks then we'll assume they're
        # correct and exit the loop.  If the values keep changing, then
        # we continue looping until we reach MAXIMUM_LOOP_COUNT or until
        # the values "stabilize".
        if [ "${player_str}" != "${cached_player_str}" ] || [ "${turn_num}" != "${cached_turn_num}" ]; then
            cached_player_str="${player_str}"
            cached_turn_num="${turn_num}"
        else
            break
        fi
    fi

    sleep 5
    loop_counter=$((loop_counter+1))
done

printf "Turn #%s\nPlayers Who Need To Take Their Turn: %s\n" "${turn_num}" "${player_str}"
notification_string="Turn #${turn_num}: Weekly Notification: The game is waiting for the following players to take their turns: ${player_str}"

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
