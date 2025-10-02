#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# This JSON file is updated whenever a player disconnects
# from civ.  A user could abuse this by constantly connecting,
# selecting "Next Turn", re-connecting, cancelling their "Next
# Turn", disconnecting, and so on and so forth.  However, this
# is tedious and annoying to do.
JSON_FILE="${CIV_DATA_ROOT}/disconnected_turn_status.json"
MAXIMUM_LOOP_COUNT=12
SQLITE_DB="TurnStatus-1.db"

function db_handler {
    while : ; do
        if (( loop_counter > MAXIMUM_LOOP_COUNT )); then
            # Exit (give up) if we have looped 12 times (1 minute).
            # supervisord will restart this script.
            printf "Unable to extract TurnNum and PlayersWhoNeedToTakeTheirTurn values found in %s.\nTurnNum: %s\nPlayersWhoNeedToTakeTheirTurn: %s\nNot sending notification and exiting...\n" "${SQLITE_DB}" "${turn_num}" "${player_str}"
            exit 1
        fi

        # Query the sqlite DB for the values we need.
        # We disable errexit because we don't want to
        # bomb the script if the query fails and will
        # retry instead.
        set +o errexit
        sqlite_query=$(sqlite3 "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}" ".mode csv" "SELECT * FROM SimpleValues;")
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

        # Verify the fields we extracted are not empty (which can happen).
        if [ "${player_str}" != "" ] && [ "${turn_num}" != "" ]; then
            break
        fi

        sleep 5
        loop_counter=$((loop_counter+1))
    done

    printf "Player disconnected.\nTurn #%s\nPlayers Who Need To Take Their Turn: %s\n" "${turn_num}" "${player_str}"

    old_turn_num=""
    old_player_str=""

    # Get the saved JSON file's values
    json_file_params=$(python3 /usr/local/bin/json_file_helper.py --config "${JSON_FILE}" print --parameters turn players)
    while IFS= read -r line; do
        if [[ "${line}" =~ ^turn:.* ]]; then
            old_turn_num=$(echo "${line}" | cut --delimiter ':' --fields 2-)
        elif [[ "${line}" =~ ^players:.* ]]; then
            old_player_str=$(echo "${line}" | cut --delimiter ':' --fields 2-)
        fi
    done <<< "${json_file_params}"

    printf "(Old) Turn #%s\n(Old) Players Who Need To Take Their Turn: %s\n" "${old_turn_num}" "${old_player_str}"

    # Update the JSON file if the values changed
    if [ "${player_str}" != "${old_player_str}" ] || [ "${turn_num}" != "${old_turn_num}" ]; then
        if [ "${NTFY_TOPIC}" != "" ]; then
            curl -d "Turn #${turn_num}: The game is waiting for the following players to take their turns: ${player_str}" ntfy.sh/${NTFY_TOPIC}
        fi
        python3 /usr/local/bin/json_file_helper.py --config "${JSON_FILE}" update --turn "${turn_num}" --players "${player_str}"
    fi
}

function main_handler {
    # Create the json config file if it does not exist.
    if [ ! -f "${JSON_FILE}" ]; then
        echo '{}' > "${JSON_FILE}"
    fi

    initial_db=0

    # This loop handles the edge case when the sqlite DB has not
    # been created yet.
    while : ; do
        loop_counter=1
        player_str=""
        turn_num=""

        printf "Verifying %s file is non-empty...\n" "${SQLITE_DB}"
        # Note that if we manually create the file here, then Civ V
        # fails to create/update the database, therefore we we wait
        # here for Civ V to create it itself.
        if [ ! -s "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}" ]; then
            sleep 30
            continue
            initial_db=1
        fi
        printf "%s file exists and is non-empty.\n" "${SQLITE_DB}"

        if [ "${initial_db}" -eq 1 ]; then
            db_handler
        fi

        break
    done

    # This is the main loop that handles updates to the sqlite DB
    # after it has been created.
    while : ; do
        loop_counter=1
        player_str=""
        turn_num=""

        printf "Waiting for update to SQLite file %s...\n" "${SQLITE_DB}"
        inotifywait -e modify -q "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}"

        db_handler
    done
}

main_handler
