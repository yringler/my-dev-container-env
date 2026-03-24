#!/usr/bin/env bash
# devbox.sh — convenience wrapper for your dev container
# Usage: ./devbox.sh [command]
#   ./devbox.sh          → shell into running container (starts if needed)
#   ./devbox.sh start    → start container in background
#   ./devbox.sh stop     → stop container
#   ./devbox.sh rebuild  → rebuild image from scratch and restart
#   ./devbox.sh status   → show container status
#   ./devbox.sh clean    → remove container AND home volume (nuclear reset)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="devbox"

cd "$SCRIPT_DIR"

cmd="${1:-shell}"

case "$cmd" in
  shell)
    # Start if not running
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
      echo "→ Container not running, starting..."
      docker compose up -d
      sleep 1
    fi
    echo "→ Attaching shell..."
    docker exec -it "$CONTAINER_NAME" /bin/bash
    ;;

  start)
    docker compose up -d
    echo "→ devbox started"
    ;;

  stop)
    docker compose stop
    echo "→ devbox stopped"
    ;;

  rebuild)
    echo "→ Rebuilding image (this will take a while)..."
    docker compose down
    docker compose build --no-cache
    docker compose up -d
    echo "→ devbox rebuilt and started"
    echo "   Note: devbox-home volume was preserved. Run './devbox.sh clean' to reset it."
    ;;

  status)
    docker compose ps
    ;;

  clean)
    read -rp "This will delete the container AND devbox-home volume (all ad-hoc installs). Continue? [y/N] " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      docker compose down -v
      echo "→ Container and volumes removed"
    else
      echo "→ Cancelled"
    fi
    ;;

  *)
    echo "Unknown command: $cmd"
    echo "Usage: $0 [shell|start|stop|rebuild|status|clean]"
    exit 1
    ;;
esac
