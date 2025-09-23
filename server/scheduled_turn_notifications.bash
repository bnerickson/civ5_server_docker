#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

SQLITE_DB="DynamicTurnStatus-1.db"
MAXIMUM_LOOP_COUNT=12

echo "Verifying ${SQLITE_DB} file exists and is non-empty"
# Exit if the db does not exist or is empty.
if [ ! -f "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}" ]; then
    exit 0
elif [ ! -s "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}" ]; then
    exit 0
fi

loop_counter=1
player_str=""
turn_num=""

while : ; do
    if (( loop_counter > MAXIMUM_LOOP_COUNT )); then
        # Exit (give up) if we have looped 12 times (1 minute).
        exit 0
    fi

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

    if [ "${player_str}" != "" -a "${turn_num}" != "" ]; then
        break
    fi

    sleep 5
    loop_counter=$((loop_counter+1))
done

echo "Turn #${turn_num}"
echo "Players Who Need To Take Their Turn: ${player_str}"

curl -d "Turn #${turn_num}: Weekly Notification: The game is waiting for the following players to take their turns: ${player_str}" ntfy.sh/${NFTY_TOPIC}
