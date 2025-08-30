#!/bin/bash

JSON_FILE="${CIV_DATA_ROOT}/current_turn_players.json"
SQLITE_DB="DynamicTurnStatus-1.db"

echo "Verifying ${SQLITE_DB} file is non-empty"
if [ ! -s "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}" ]; then
    exit 0
fi

PLAYER_STR=$(sqlite3 "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}" "SELECT Value FROM SimpleValues WHERE Name = 'PlayersWhoNeedToTakeTheirTurn';")
if [ ${?} -ne 0 ]; then
    exit 0
fi

TURN_NUM=$(sqlite3 "${CIV_DATA_ROOT}/ModUserData/${SQLITE_DB}" "SELECT Value FROM SimpleValues WHERE Name = 'TurnNum';")
if [ ${?} -ne 0 ]; then
    exit 0
fi

echo "Turn #: ${TURN_NUM}"
echo "The following players still need to take their turns:"
echo ${PLAYER_STR}

# Create json config file if it does not exist.
if [ ! -f "${JSON_FILE}" ]; then
    echo '{}' > "${JSON_FILE}"
fi

OLD_TURN_NUM=$(python3 /usr/local/bin/json_file_helper.py --config "${JSON_FILE}" print --parameter turn)
OLD_PLAYER_STR=$(python3 /usr/local/bin/json_file_helper.py --config "${JSON_FILE}" print --parameter players)

if [ "${PLAYER_STR}" != "${OLD_PLAYER_STR}" ] || [ "${TURN_NUM}" != "${OLD_TURN_NUM}" ]; then
    if [ "${NFTY_TOPIC}" != "" ]; then
        curl -d "Turn #${TURN_NUM}: The following players still need to take their turns: ${PLAYER_STR}" ntfy.sh/${NFTY_TOPIC}
    fi
    python3 /usr/local/bin/json_file_helper.py --config "${JSON_FILE}" update --turn "${TURN_NUM}" --players "${PLAYER_STR}"
fi
