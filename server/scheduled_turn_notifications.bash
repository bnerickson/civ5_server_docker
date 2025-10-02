#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

MAXIMUM_LOOP_COUNT=12
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
            turn_num=$(echo "${line}" | cut --delimiter ',' --fields 2-)
        elif [[ "${line}" =~ ^PlayersWhoNeedToTakeTheirTurn,.* ]]; then
            # Remove the leading and trailing quotes and commas
            # when there are multiple players.
            player_str=$(echo "${line}" | cut --delimiter ',' --fields 2- | sed 's/^"//g' | sed 's/, ".$//g')
        fi
    done <<< "${sqlite_query_formatted}"

    if [ "${player_str}" != "" ] && [ "${turn_num}" != "" ]; then
        break
    fi

    sleep 5
    loop_counter=$((loop_counter+1))
done

printf "Turn #%s\nPlayers Who Need To Take Their Turn: %s\n" "${turn_num}" "${player_str}"

curl -d "Turn #${turn_num}: Weekly Notification: The game is waiting for the following players to take their turns: ${player_str}" ntfy.sh/${NTFY_TOPIC}
