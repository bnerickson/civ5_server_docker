#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

JSON_FILE="${CIV_DATA_ROOT}/disconnected_turn_status.json"
MAXIMUM_LOOP_COUNT=12
SQLITE_DB=("TurnStatus-1.db" "DynamicTurnStatus-1.db")

for db in "${SQLITE_DB[@]}"; do
    printf "DB: %s\n    Verifying %s file exists and is non-empty...\n" "${db}" "${db}"
    # Exit if the db does not exist or is empty.
    if [ ! -f "${CIV_DATA_ROOT}/ModUserData/${db}" ]; then
        printf "SQLite DB %s does not exist.  Continuing...\n" "${db}"
        continue
    elif [ ! -s "${CIV_DATA_ROOT}/ModUserData/${db}" ]; then
        printf "SQLite DB %s is empty.  Continuing...\n" "${db}"
        continue
    fi
    printf "    %s file exists and is non-empty.\n" "${db}"

    loop_counter=1
    player_str=""
    turn_num=""

    while : ; do
        if (( loop_counter > MAXIMUM_LOOP_COUNT )); then
            # Exit (give up) if we have looped 12 times (1 minute).
            printf "Unable to extract TurnNum and PlayersWhoNeedToTakeTheirTurn values found in %s.\n    TurnNum: %s\n    PlayersWhoNeedToTakeTheirTurn: %s\n    Not sending notification and continuing...\n" "${db}" "${turn_num}" "${player_str}"
            break
        fi

        # Query the sqlite DB for the values we need.
        # We disable errexit because we don't want to
        # bomb the script if the query fails and will
        # retry instead.
        set +o errexit
        sqlite_query=$(sqlite3 "${CIV_DATA_ROOT}/ModUserData/${db}" ".mode csv" "SELECT * FROM SimpleValues;" | sed $'s/\x1f/, /g')
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
            break
        fi

        sleep 5
        loop_counter=$((loop_counter+1))
    done

    printf "    %s:TurnNum: %s\n    %s:PlayersWhoNeedToTakeTheirTurn: %s\n" "${db}" "${turn_num}" "${db}" "${player_str}"
done

printf "JSON File %s Contents:\n    %s\n" "${JSON_FILE}" "$(cat "${JSON_FILE}")"
