#!/bin/sh
set -e

PUID=${PUID:-1000}
PGID=${PGID:-1000}

echo "Setting up user (UID: $PUID, GID: $PGID)..."
groupadd -g $PGID -o hytale 2>/dev/null || true
useradd -u $PUID -g $PGID -o -m -s /bin/bash hytale 2>/dev/null || true
chown -R $PUID:$PGID /data
chmod -R 755 /data

exec gosu $PUID:$PGID /scripts/start.sh
