# Polyglot Dev Container

A Docker-based development environment on Ubuntu 24.04 with support for C#/.NET, Node/TypeScript, Dart/Flutter, Go, Rust, and Hugo. Connects via SSH, making it compatible with VS Code Remote SSH and similar tools.

## Included toolchains

| Tool | Version |
|------|---------|
| Go | 1.26.0 |
| Hugo (extended) | 0.159.0 |
| Node.js (via fnm) | 24 |
| .NET SDK | LTS |
| Flutter | 3.27.1 |

**Global npm packages:** TypeScript, ts-node, tsx, pnpm, yarn, @angular/cli, prettier, eslint

**Go tools:** gopls, delve, staticcheck

## Prerequisites

- Docker and Docker Compose
- An SSH key at `~/.ssh/id_ed25519.pub`
- A `~/dev` directory for your repos

## Usage

```bash
# Shell into the container (starts it if not running)
./devbox.sh

# Other commands
./devbox.sh start    # start in background
./devbox.sh stop     # stop the container
./devbox.sh rebuild  # rebuild image from scratch and restart
./devbox.sh status   # show container status
./devbox.sh clean    # remove container AND volumes (nuclear reset)
```

## VS Code

Connect via **Remote SSH** to `localhost` (the container uses `network_mode: host` and exposes port 2222). VS Code Server extensions are persisted in a named volume (`vscode-server`).

## Volumes

| Volume | Purpose |
|--------|---------|
| `~/dev` (bind mount) | Your local repos, mounted at `/home/ubuntu/dev` |
| `devbox-history` | Persists bash history across rebuilds |
| `vscode-server` | Persists VS Code Server extensions |
