#!/bin/bash

JSON_FILE="${CIV_DATA_ROOT}/current_turn_players.json"
SQLITE_DB="TurnStatus-1.db"

while : ; do
    echo "Verifying ${SQLITE_DB} file is non-empty"
    if [ ! -s "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}" ]; then
        sleep 30
        continue
    fi

    echo "Waiting for sqlite file update..."
    inotifywait -e modify -q "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}"
    while : ; do
        PLAYER_STR=$(sqlite3 "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}" ".mode column" "SELECT Value FROM SimpleValues WHERE Name = 'PlayersWhoNeedToTakeTheirTurn';" | tail -n +3 | sed 's/,/~/g' | paste --serial --delimiters=, - | sed 's/,/, /g')
        if [ "${?}" -eq 0 -a "${PLAYER_STR}" != "" ]; then
            break
        fi
        sleep 5
    done
    while : ; do
        TURN_NUM=$(sqlite3 "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}" "SELECT Value FROM SimpleValues WHERE Name = 'TurnNum';")
        if [ "${?}" -eq 0 -a "${TURN_NUM}" != "" ]; then
            break
        fi
        sleep 5
    done

    echo "Turn #: ${TURN_NUM}"
    echo "Player disconnected."
    echo "The game is waiting for the following players to make their turns:"
    echo ${PLAYER_STR}

    # Create json config file if it does not exist.
    if [ ! -f "${JSON_FILE}" ]; then
        echo '{}' > "${JSON_FILE}"
    fi

    OLD_TURN_NUM=$(python3 /usr/local/bin/json_file_helper.py --config "${JSON_FILE}" print --parameter turn)
    OLD_PLAYER_STR=$(python3 /usr/local/bin/json_file_helper.py --config "${JSON_FILE}" print --parameter players)

    if [ "${PLAYER_STR}" != "${OLD_PLAYER_STR}" ] || [ "${TURN_NUM}" != "${OLD_TURN_NUM}" ]; then
        if [ "${NFTY_TOPIC}" != "" ]; then
            curl -d "Turn #${TURN_NUM}: The game is waiting for the following players to make their turns: ${PLAYER_STR}" ntfy.sh/${NFTY_TOPIC}
        fi
        python3 /usr/local/bin/json_file_helper.py --config "${JSON_FILE}" update --turn "${TURN_NUM}" --players "${PLAYER_STR}"
    fi
done
