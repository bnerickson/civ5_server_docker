#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

JSON_FILE="${CIV_DATA_ROOT}/disconnected_turn_status.json"
MAXIMUM_LOOP_COUNT=12
SQLITE_DB=("TurnStatus-1.db" "DynamicTurnStatus-1.db")

for db in "${SQLITE_DB[@]}"; do
    echo "Verifying ${SQLITE_DB} file exists and is non-empty"
    # Exit if the db does not exist or is empty.
    if [ ! -f "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}" ]; then
        continue
    elif [ ! -s "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}" ]; then
        continue
    fi

    loop_counter=1
    player_str=""
    turn_num=""

    while : ; do
        if (( loop_counter > MAXIMUM_LOOP_COUNT )); then
            # Exit (give up) if we have looped 12 times (1 minute).
            break
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

    echo "DB: ${db}"
    echo "Turn #${turn_num}"
    echo "Players Who Need To Take Their Turn: ${player_str}"
done

echo "JSON File: ${JSON_FILE}"
cat "${JSON_FILE}"
echo ""
