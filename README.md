# Hytale Server Docker Container

A Docker container for running a Hytale dedicated server with automated OAuth authentication, token refresh, and server management.

## Quick Start

```bash
# Create docker-compose.yaml
curl -o docker-compose.yaml https://raw.githubusercontent.com/hoobio/hytale-server/main/docker-compose.example.yaml

# Start the container
docker compose up -d

# Follow authentication prompts in logs
docker compose logs -f
```

On first run, you'll be prompted to authenticate:
1. Open the provided URL in your browser
2. Enter the displayed code
3. Sign in with your Hytale account
4. The server will start automatically after authentication

## Configuration

All configuration is done through environment variables in your `docker-compose.yaml` file.

### Server Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_NAME` | `"Hoobio Hytale Server"` | Your server's display name |
| `PORT` | `5520` | Server port (must match port mapping) |

### Server Settings (Optional)

| Variable | Default | Description |
|----------|---------|-------------|
| `PATCHLINE` | `release` | Server version channel: `release` or `pre-release` |
| `MOTD` | `""` | Message of the day shown to connecting players |
| `PASSWORD` | `""` | Server password (empty = no password required) |
| `MAX_PLAYERS` | `100` | Maximum concurrent players allowed |
| `MAX_VIEW_RADIUS` | `32` | Maximum view distance in chunks |

### Container Behavior (Optional)

| Variable | Default | Description |
|----------|---------|-------------|
| `UPDATE_ON_STARTUP` | `true` | Check for and download server updates on startup |
| `REFRESH_INTERVAL` | `86400` | OAuth token refresh interval in seconds (24 hours) |
| `PUID` | `1000` | User ID for file ownership |
| `PGID` | `1000` | Group ID for file ownership |
| `LOG_FILTERS` | | Pipe-separated regex patterns to filter from logs |

### Example Configuration

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
      SERVER_NAME: "My Hytale Server"
      PORT: "5520"
      PASSWORD: "secret123"
      UPDATE_ON_STARTUP: "true"
      
    stdin_open: true
    tty: true
```

## Features

- **Automated OAuth Authentication**: Device flow authentication with automatic token refresh
- **Token Management**: Secure refresh token storage with daily rotation (configurable)
- **Automatic Updates**: Optional server binary updates on startup
- **Log Filtering**: Built-in filtering of common spam warnings, extensible via `LOG_FILTERS`
- **Graceful Shutdown**: Proper cleanup of background processes and server state
- **File Permissions**: Configurable UID/GID for proper file ownership

## Volume Mounts

The container uses `/data` for persistent storage:

```
/data/
├── server/           # Hytale server binaries and files
├── credentials.json  # OAuth refresh token (keep secure!)
└── ...              # Server data and world files
```

**Important**: Keep `credentials.json` secure. It contains your refresh token for Hytale account authentication.

## Port Mapping

The container exposes port 5520 by default. Ensure your `PORT` environment variable matches your port mapping:

```yaml
ports:
  - "25565:25565"  # Custom port example
environment:
  PORT: "25565"
```

## Authentication

The container uses OAuth device flow for authentication:

1. **First Run**: You'll be prompted to authenticate via browser
2. **Token Storage**: Refresh token is saved to `/data/credentials.json`
3. **Auto Refresh**: Token is automatically refreshed based on `REFRESH_INTERVAL`
4. **Re-authentication**: Delete `credentials.json` to re-authenticate

### Manual Re-authentication

```bash
docker compose exec hytale-server rm /data/credentials.json
docker compose restart
```

## Log Filtering

The container automatically filters common spam warnings. To add custom filters:

```yaml
environment:
  # Filter connection timeouts and debug messages
  LOG_FILTERS: "ERROR.*connection timeout|DEBUG.*verbose"
```

Filters use grep extended regex syntax, separated by pipes (`|`).

## Troubleshooting

### Server won't start after authentication
- Check logs: `docker compose logs -f`
- Verify credentials: `docker compose exec hytale-server cat /data/credentials.json`
- Try re-authentication by deleting credentials.json

### Port already in use
- Change the host port in port mapping: `"25565:5520"`
- Or change the server port: `PORT: "25565"` (update both port mapping and environment)

### Permission errors
- Set `PUID` and `PGID` to match your host user:
  ```bash
  PUID: "1000"
  PGID: "1000"
  ```

### Updates not applying
- Ensure `UPDATE_ON_STARTUP: "true"`
- Check available disk space
- Manually trigger update: `docker compose restart`

## Development

For development/testing, use a shorter refresh interval:

```yaml
environment:
  UPDATE_ON_STARTUP: "false"  # Skip updates for faster restarts
  REFRESH_INTERVAL: "10"      # Refresh every 10 seconds
```

## Security Notes

- **credentials.json**: Contains sensitive OAuth tokens - keep secure and backed up
- **Password**: Use strong passwords if setting `PASSWORD` environment variable
- **Network**: Consider using a firewall or reverse proxy for internet-facing servers
- **Updates**: Keep the container image updated for security patches

## Support

- **Issues**: https://github.com/hoobio/hytale-server/issues
- **Hytale**: https://hytale.com

## License

This container is provided as-is for running Hytale servers. Hytale is a trademark of Hypixel Studios.
