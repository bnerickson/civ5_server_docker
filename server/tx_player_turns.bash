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

initial_db=0

while : ; do
    echo "Verifying ${SQLITE_DB} file is non-empty..."
    # Note that if we manually create the file here, then Civ V
    # fails to create/update the database itself, so we'll just
    # have to wait.
    if [ ! -s "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}" ]; then
        initial_db=1
        sleep 30
        continue
    fi

    loop_counter=1
    player_str=""
    turn_num=""

    if [ "${initial_db}" -eq 1 ]; then
        # If the db was just created, then we don't need to wait for
        # it to be updated because it has just been created.
        initial_db=0
    else
        echo "Waiting for sqlite file update..."
        inotifywait -e modify -q "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}"
    fi
    while : ; do
        if (( loop_counter > MAXIMUM_LOOP_COUNT )); then
            # Exit (give up) if we have looped 12 times (1 minute).
            # supervisord will restart this script.
            exit 0
        fi

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

        if [ "${player_str}" != "" -a "${turn_num}" != "" ]; then
            break
        fi

        sleep 5
        loop_counter=$((loop_counter+1))
    done

    echo "Player disconnected."
    echo "Turn #${turn_num}"
    echo "Players Who Need To Take Their Turn: ${player_str}"

    # Create json config file if it does not exist.
    if [ ! -f "${JSON_FILE}" ]; then
        echo '{}' > "${JSON_FILE}"
    fi

    old_turn_num=""
    old_player_str=""

    json_file_params=$(python3 /usr/local/bin/json_file_helper.py --config "${JSON_FILE}" print --parameters turn players)
    while IFS= read -r line; do
        if [[ "${line}" =~ ^turn:.* ]]; then
            old_turn_num=$(echo "${line}" | cut --delimiter ':' --fields 2-)
        elif [[ "${line}" =~ ^players:.* ]]; then
            old_player_str=$(echo "${line}" | cut --delimiter ':' --fields 2-)
        fi
    done <<< "${json_file_params}"

    echo "(Old) Turn #${old_turn_num}"
    echo "(Old) Players Who Need To Take Their Turn: ${old_player_str}"

    if [ "${player_str}" != "${old_player_str}" ] || [ "${turn_num}" != "${old_turn_num}" ]; then
        if [ "${NFTY_TOPIC}" != "" ]; then
            curl -d "Turn #${turn_num}: The game is waiting for the following players to take their turns: ${player_str}" ntfy.sh/${NFTY_TOPIC}
        fi
        python3 /usr/local/bin/json_file_helper.py --config "${JSON_FILE}" update --turn "${turn_num}" --players "${player_str}"
    fi
done
