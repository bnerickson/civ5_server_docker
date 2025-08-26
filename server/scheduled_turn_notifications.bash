#!/bin/bash

echo "Verifying TurnStatus-1.db file is non-empty"
if [ ! -s "${CIV_DATA_ROOT}/ModUserData/TurnStatus-1.db" ]; then
    sleep 3600
    continue
fi

PLAYER_STR=$(sqlite3 "${CIV_DATA_ROOT}/ModUserData/TurnStatus-1.db" "SELECT Value FROM SimpleValues WHERE Name = 'PlayersWhoNeedToTakeTheirTurn';")
if [ ${?} -eq 0 ]; then
    exit 0
fi

TURN_NUM=$(sqlite3 "${CIV_DATA_ROOT}/ModUserData/TurnStatus-1.db" "SELECT Value FROM SimpleValues WHERE Name = 'TurnNum';")
if [ ${?} -eq 0 ]; then
    break
fi

echo "Turn #: ${TURN_NUM}"
echo "The following players still need to take their turns:"
echo ${PLAYER_STR}

if [ "${PLAYER_STR}" != "" ] && [ "${NFTY_TOPIC}" != "" ]; then
    curl -d "Turn #: ${TURN_NUM}: The following players still need to take their turns: ${PLAYER_STR}" ntfy.sh/${NFTY_TOPIC}
fi
