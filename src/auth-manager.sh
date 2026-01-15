#!/bin/sh
set -e

CREDENTIALS_FILE="/data/credentials.json"

refresh_oauth_token() {
    local LOG_PREFIX="${1:-}"
    
    [ ! -f "$CREDENTIALS_FILE" ] && { echo "${LOG_PREFIX}Credentials file not found"; return 1; }
    
    local REFRESH_TOKEN=$(jq -r '.refreshToken // empty' "$CREDENTIALS_FILE")
    [ -z "$REFRESH_TOKEN" ] && { echo "${LOG_PREFIX}No refresh token found"; return 1; }
    
    local TOKEN_RESPONSE=$(curl -s -X POST "https://oauth.accounts.hytale.com/oauth2/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=hytale-server" \
      -d "grant_type=refresh_token" \
      -d "refresh_token=$REFRESH_TOKEN")
    
    local ERROR=$(echo "$TOKEN_RESPONSE" | jq -r '.error // empty')
    [ -n "$ERROR" ] && { echo "${LOG_PREFIX}Failed to refresh token: $ERROR"; return 1; }
    
    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
    local NEW_REFRESH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.refresh_token // empty')
    [ -n "$NEW_REFRESH_TOKEN" ] && REFRESH_TOKEN="$NEW_REFRESH_TOKEN"
    
    echo "{\"refreshToken\":\"$REFRESH_TOKEN\"}" > "${CREDENTIALS_FILE}.tmp" && mv "${CREDENTIALS_FILE}.tmp" "$CREDENTIALS_FILE"
    echo "${LOG_PREFIX}Successfully refreshed access token"
    return 0
}

device_flow_auth() {
    echo "Starting OAuth device flow..."

    DEVICE_RESPONSE=$(curl -s -X POST "https://oauth.accounts.hytale.com/oauth2/device/auth" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=hytale-server" \
      -d "scope=openid offline auth:server")

    DEVICE_CODE=$(echo "$DEVICE_RESPONSE" | jq -r '.device_code')
    VERIFICATION_URI=$(echo "$DEVICE_RESPONSE" | jq -r '.verification_uri_complete')
    EXPIRES_IN=$(echo "$DEVICE_RESPONSE" | jq -r '.expires_in')
    INTERVAL=$(echo "$DEVICE_RESPONSE" | jq -r '.interval')

    echo ""
    echo "=========================================="
    echo "Please authenticate using the URL below:"
    echo ""
    echo "  $VERIFICATION_URI"
    echo ""
    echo "=========================================="
    echo ""
    echo "Waiting for authentication..."

    END_TIME=$(($(date +%s) + EXPIRES_IN))
    while [ $(date +%s) -lt $END_TIME ]; do
        sleep $INTERVAL
        
        TOKEN_RESPONSE=$(curl -s -X POST "https://oauth.accounts.hytale.com/oauth2/token" \
          -H "Content-Type: application/x-www-form-urlencoded" \
          -d "client_id=hytale-server" \
          -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
          -d "device_code=$DEVICE_CODE")
        
        ERROR=$(echo "$TOKEN_RESPONSE" | jq -r '.error // empty')
        
        if [ -z "$ERROR" ]; then
            ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
            echo "{\"refreshToken\":\"$(echo "$TOKEN_RESPONSE" | jq -r '.refresh_token')\"}" > "$CREDENTIALS_FILE"
            return 0
        elif [ "$ERROR" != "authorization_pending" ] && [ "$ERROR" != "slow_down" ]; then
            echo "Authentication failed: $ERROR"
            return 1
        fi
    done
    
    echo "Authentication timed out"
    return 1
}

setup_game_session() {
    echo "Fetching account profiles..."
    PROFILES_RESPONSE=$(curl -s -X GET "https://account-data.hytale.com/my-account/get-profiles" \
      -H "Authorization: Bearer $ACCESS_TOKEN")
    
    if ! echo "$PROFILES_RESPONSE" | jq empty 2>/dev/null; then
        echo "ERROR: Invalid JSON response from profiles API:"
        echo "$PROFILES_RESPONSE"
        return 1
    fi
    
    OWNER_UUID=$(echo "$PROFILES_RESPONSE" | jq -r '.profiles[0].uuid // empty')
    
    if [ -z "$OWNER_UUID" ]; then
        ERROR=$(echo "$PROFILES_RESPONSE" | jq -r '.error // empty')
        if [ -n "$ERROR" ]; then
            echo "Token invalid: $ERROR"
            echo "$(echo "$PROFILES_RESPONSE" | jq -r '.error_description // empty')"
            rm -f "$CREDENTIALS_FILE"
            exec "$0" init
        fi
        echo "Response was: $PROFILES_RESPONSE"
        return 1
    fi
    
    echo "Using profile: $(echo "$PROFILES_RESPONSE" | jq -r '.profiles[0].username') ($OWNER_UUID)"
    
    echo "Creating game session..."
    SESSION_RESPONSE=$(curl -s -X POST "https://sessions.hytale.com/game-session/new" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"uuid\":\"$OWNER_UUID\"}")
    
    SESSION_TOKEN=$(echo "$SESSION_RESPONSE" | jq -r '.sessionToken // empty')
    IDENTITY_TOKEN=$(echo "$SESSION_RESPONSE" | jq -r '.identityToken // empty')
    
    [ -z "$SESSION_TOKEN" ] && { echo "Failed to create game session"; echo "Response: $SESSION_RESPONSE"; return 1; }
    return 0
}

cmd_auth() {
    ACCESS_TOKEN=""
    
    if [ -f "$CREDENTIALS_FILE" ]; then
        echo "Refreshing access token..."
        if ! refresh_oauth_token ""; then
            echo "Refresh token invalid, starting OAuth flow..."
            rm -f "$CREDENTIALS_FILE"
        fi
    fi
    
    [ -z "$ACCESS_TOKEN" ] && { device_flow_auth || exit 1; }
}

cmd_session() {
    exec 3>&1 1>&2
    ACCESS_TOKEN=""
    
    [ ! -f "$CREDENTIALS_FILE" ] && { echo "Not authenticated. Run 'auth' first."; exit 1; }
    
    refresh_oauth_token "" || { echo "Failed to refresh token"; exit 1; }
    setup_game_session || { echo "Failed to set up game session"; exit 1; }
    
    echo "Game session created!"
    echo "export SESSION_TOKEN='$SESSION_TOKEN'" >&3
    echo "export IDENTITY_TOKEN='$IDENTITY_TOKEN'" >&3
    echo "export OWNER_UUID='$OWNER_UUID'" >&3
}

cmd_init() {
    cmd_auth
    cmd_session
}

cmd_refresh_daemon() {   
    REFRESH_INTERVAL=${REFRESH_INTERVAL:-86400}
    echo "[Token Refresh] Background process started (interval: ${REFRESH_INTERVAL}s)"
    
    while true; do
        sleep $REFRESH_INTERVAL
        [ ! -f "$CREDENTIALS_FILE" ] && { echo "[Token Refresh] Credentials file not found"; continue; }
        echo "[Token Refresh] Refreshing access token..."
        refresh_oauth_token "[Token Refresh] "
    done
}

cmd_refresh_once() {
    [ -f "$CREDENTIALS_FILE" ] && refresh_oauth_token "" || echo "No credentials file found"
}

cmd_generate_downloader_creds() {
    DOWNLOADER_CREDS_FILE="${1:-/data/server/.hytale-downloader-credentials.json}"
    PATCHLINE="${2:-release}"
    
    [ ! -f "$CREDENTIALS_FILE" ] && { echo "Credentials file not found. Run 'init' first."; exit 1; }
    
    refresh_oauth_token "" || { echo "Failed to refresh token"; exit 1; }
    
    local REFRESH_TOKEN=$(jq -r '.refreshToken // empty' "$CREDENTIALS_FILE")
    local EXPIRES_AT=$(($(date +%s) + 3600))
    
    echo "{\"access_token\":\"$ACCESS_TOKEN\",\"refresh_token\":\"$REFRESH_TOKEN\",\"expires_at\":$EXPIRES_AT,\"branch\":\"$PATCHLINE\"}" > "${DOWNLOADER_CREDS_FILE}.tmp" && \
        mv "${DOWNLOADER_CREDS_FILE}.tmp" "$DOWNLOADER_CREDS_FILE"
    echo "Generated credentials file: $DOWNLOADER_CREDS_FILE"
}

COMMAND="${1:-init}"
case "$COMMAND" in
    auth) cmd_auth ;;
    session) cmd_session ;;
    init) cmd_init ;;
    refresh-daemon) cmd_refresh_daemon ;;
    refresh-once) cmd_refresh_once ;;
    generate-downloader-creds) shift; cmd_generate_downloader_creds "$@" ;;
    *) echo "Usage: $0 {auth|session|init|refresh-daemon|refresh-once|generate-downloader-creds}"; exit 1 ;;
esac
