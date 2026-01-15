# Hytale Server Docker Container

[![Build and Publish Docker Image](https://github.com/hoobio/hytale-server/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/hoobio/hytale-server/actions/workflows/docker-publish.yml)
[![Docker Image Version (latest by date)](https://img.shields.io/docker/v/hoobio/hytale-server)](https://hub.docker.com/r/hoobio/hytale-server)
[![Docker Image Size (latest by date)](https://img.shields.io/docker/image-size/hoobio/hytale-server)](https://hub.docker.com/r/hoobio/hytale-server)
[![Docker Pulls](https://img.shields.io/docker/pulls/hoobio/hytale-server)](https://hub.docker.com/r/hoobio/hytale-server)
[![GitHub last commit](https://img.shields.io/github/last-commit/hoobio/hytale-server)](https://github.com/hoobio/hytale-server/commits/main)
[![GitHub issues](https://img.shields.io/github/issues/hoobio/hytale-server)](https://github.com/hoobio/hytale-server/issues)
[![License](https://img.shields.io/github/license/hoobio/hytale-server)](https://github.com/hoobio/hytale-server/blob/main/LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/hoobio/hytale-server?style=social)](https://github.com/hoobio/hytale-server/stargazers)

A Docker container for running a Hytale dedicated server. Features **automated OAuth authentication**, token refreshing, log filtering, and automatic updates.

---

## 🚀 Usage

### 1. Docker Compose (Recommended)

Copy the following into a `docker-compose.yaml` file, or reference [docker-compose.example.yaml](docker-compose.example.yaml)

```yaml
services:
  hytale-server:
    image: ghcr.io/hoobio/hytale-server:latest
    container_name: hytale-server
    restart: unless-stopped
    ports:
      - "5520:5520/udp"
    volumes:
      - ./data:/data
    environment:
      # Game Settings
      SERVER_NAME: "My Hytale Server"
      PORT: "5520"
      PASSWORD: "changeme"
      MAX_PLAYERS: "100"
      
      # Container Settings
      UPDATE_ON_STARTUP: "false" # Set to false if you don't want to download the 1.5gb binary every launch
      PUID: "1000"
      PGID: "1000"
    
    stdin_open: true
    tty: true
```

### 2. Start and Authenticate

Start the container and attach to the logs to see the authentication prompts:

```bash
docker compose up -d
docker compose logs -f

```

**⚠️ You must authenticate manually on the first run**
Once finished, the container will save your refresh token to `/data/credentials.json` and handle future authentication automatically.

---

## ⚙️ Configuration

### Game Settings
*Configure the in-game experience.*

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_NAME` | `Hoobio Hytale Server` | The display name of your server. |
| `PORT` | `5520` | Internal server port (ensure this matches `ports` mapping). |
| `PASSWORD` | `""` | Server password (leave empty to disable). |
| `MOTD` | `""` | Message of the Day displayed to players. |
| `MAX_PLAYERS` | `100` | Maximum concurrent players. |
| `MAX_VIEW_RADIUS`| `32` | Max view distance in chunks. |
| `PATCHLINE` | `release` | `release` or `pre-release`. |

### Container Settings
*Configure how the Docker container behaves.*

| Variable | Default | Description |
|----------|---------|-------------|
| `UPDATE_ON_STARTUP`| `true` | Download server updates every time the container starts. |
| `REFRESH_INTERVAL` | `86400` | How often to refresh the OAuth token (seconds). |
| `LOG_FILTERS` | | Regex patterns (pipe-separated) to hide from logs. |
| `PUID` / `PGID` | `1000` | User/Group ID for file permissions (matches host user). |

### Backup Settings
*Configure automatic server backups.*

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKUPS_ENABLED` | `true` | Enable automatic backups. Set to `true` to enable. |
| `BACKUP_DIR` | `/data/backups` | Directory where backups are stored. |
| `BACKUP_FREQUENCY` | `30` | Backup interval in minutes. |
| `BACKUP_MAX_COUNT` | `5` | Maximum number of backups to retain. |

---

## 📂 Storage & Volumes

The container stores all persistent data in `/data`.

```text
/data/
├── server/           # The actual Hytale server binaries
├── credentials.json  # YOUR OAUTH TOKEN (Keep this safe!)
└── ...               # World files and configs
```

> **Security Note:** Back up `credentials.json`. If you lose it, you must re-authenticate. If it is stolen, others can use your session.

---

## 🛠️ Operations & Management

### Manual Re-authentication
If your token expires or you wish to switch accounts:

1.  Remove the credentials file:
    ```bash
    docker compose exec hytale-server rm /data/credentials.json
    ```
2.  Restart the container and follow the "Start and Authenticate" steps again:
    ```bash
    docker compose restart && docker compose logs -f
    ```

### Log Filtering
The server can be noisy. You can filter logs using `grep` regex syntax in the `LOG_FILTERS` variable.

**Example:** Hide connection timeouts and debug messages:
```yaml
environment:
  LOG_FILTERS: "ERROR.*connection timeout|DEBUG.*verbose"
```

### Troubleshooting

| Issue | Solution |
|-------|----------|
| **Server won't start** | Check logs (`docker compose logs -f`). If auth failed, delete `credentials.json` and restart. |
| **Port in use** | If port 5520 is taken, map a different host port: `"25565:5520"`. |
| **Permission Denied** | Ensure `PUID` and `PGID` match the user running Docker (`id -u` / `id -g`). |

---

## 🔗 Links

- **Issues:** [GitHub Issues](https://github.com/hoobio/hytale-server/issues)
- **Official Site:** [Hytale.com](https://hytale.com)

_Hytale is a trademark of Hypixel Studios. This project is not affiliated with Hypixel Studios._