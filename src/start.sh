#!/bin/sh
set -e

PORT=${PORT:-5520}
PATCHLINE=${PATCHLINE:-release}
SERVER_NAME=${SERVER_NAME:-Hoobio Hytale Server}
MOTD=${MOTD:-}
PASSWORD=${PASSWORD:-}
MAX_PLAYERS=${MAX_PLAYERS:-100}
MAX_VIEW_RADIUS=${MAX_VIEW_RADIUS:-32}
UPDATE_ON_STARTUP=${UPDATE_ON_STARTUP:-true}

DEFAULT_FILTERS="WARN.*Unused key\(s\) in|WARN.*Animation.*does not exist|WARN.*Asset key.*has incorrect format|WARN.*Creating block sets.*Failed to find.*|WARN.*Unknown channel option|WARN.*Duplicate export name for asset|WARN.*Failed to validate asset"
LOG_FILTER_PATTERN="${DEFAULT_FILTERS}${LOG_FILTERS:+|$LOG_FILTERS}"

if [ ! -f /data/server/hytale-downloader-linux-amd64 ]; then
    echo "Downloading Hytale downloader..."
    wget -q https://downloader.hytale.com/hytale-downloader.zip -O /tmp/hytale-downloader.zip
    unzip -q -j /tmp/hytale-downloader.zip hytale-downloader-linux-amd64 -d /data/server/
    chmod +x /data/server/hytale-downloader-linux-amd64
    rm /tmp/hytale-downloader.zip
fi

SHOULD_UPDATE=false
if [ "$UPDATE_ON_STARTUP" = "true" ]; then
    SHOULD_UPDATE=true
    echo "UPDATE_ON_STARTUP enabled, checking for updates..."
elif [ ! -f /data/server/Assets.zip ] || [ ! -f /data/server/HytaleServer.jar ]; then
    SHOULD_UPDATE=true
    echo "Server files missing, downloading..."
fi

if [ "$SHOULD_UPDATE" = "true" ]; then
    echo "Authenticating for downloader..."
    /scripts/auth-manager.sh auth
    /scripts/auth-manager.sh generate-downloader-creds /data/server/.hytale-downloader-credentials.json $PATCHLINE
    
    echo "Starting Hytale downloader..."
    cd /data/server
    ./hytale-downloader-linux-amd64 -check-update
    ./hytale-downloader-linux-amd64 -download-path /data/server/server.zip -patchline $PATCHLINE
    echo "Extracting server files..."
    unzip -q -o server.zip Assets.zip
    unzip -q -o -j server.zip 'Server/HytaleServer.jar'
    rm server.zip
else
    echo "Skipping server update"
fi

[ ! -f /data/config.json ] && cp /scripts/config.defaults.json /data/config.json

echo "Updating config.json..."
jq --arg serverName "$SERVER_NAME" \
   --arg motd "$MOTD" \
   --arg password "$PASSWORD" \
   --argjson maxPlayers "$MAX_PLAYERS" \
   --argjson maxViewRadius "$MAX_VIEW_RADIUS" \
   '.ServerName = $serverName | .MOTD = $motd | .Password = $password | .MaxPlayers = $maxPlayers | .MaxViewRadius = $maxViewRadius' \
   /data/config.json > /data/config.json.tmp && mv /data/config.json.tmp /data/config.json

echo "Creating game session..."
eval "$(/scripts/auth-manager.sh session)"

echo "Starting Hytale server..."
cd /data

/scripts/auth-manager.sh refresh-daemon 2>&1 &
TOKEN_REFRESH_PID=$!
echo "Started token refresh (PID: $TOKEN_REFRESH_PID)"

cleanup() {
    echo "Cleaning up..."
    [ -n "$TOKEN_REFRESH_PID" ] && kill $TOKEN_REFRESH_PID 2>/dev/null
    /scripts/auth-manager.sh refresh-once
    [ -n "$SESSION_TOKEN" ] && curl -s -X DELETE "https://sessions.hytale.com/game-session" -H "Authorization: Bearer $SESSION_TOKEN" >/dev/null 2>&1
}

trap cleanup EXIT INT TERM

java -jar /data/server/HytaleServer.jar -b 0.0.0.0:$PORT --assets /data/server/Assets.zip --session-token "$SESSION_TOKEN" --identity-token "$IDENTITY_TOKEN" --owner-uuid "$OWNER_UUID" 2>&1 | grep -v -E "$LOG_FILTER_PATTERN"