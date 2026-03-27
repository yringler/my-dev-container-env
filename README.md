# Polyglot Dev Container

A Docker-based development environment supporting C#/.NET, Node/TypeScript, Dart/Flutter, Go, and Hugo. Runs Ubuntu 24.04 LTS, accessed via SSH or VS Code Remote.

## Toolchain

| Tool | Version | Location |
|------|---------|----------|
| Go | 1.26.0 | `/usr/local/go` |
| Hugo (extended) | 0.159.0 | `/usr/local/bin` |
| Node.js (via fnm) | 24 | `~/opt/fnm` |
| .NET SDK (LTS) | latest LTS | `~/.dotnet` |
| Flutter | 3.27.1 | `~/opt/flutter` |

Global Node packages: `typescript`, `ts-node`, `tsx`, `pnpm`, `yarn`, `@angular/cli`, `prettier`, `eslint`

Go tools: `gopls`, `dlv`, `staticcheck`

## Usage

```bash
docker compose up -d
```

SSH into the container:

```bash
ssh ubuntu@localhost -p 2222
```

Or connect via VS Code Remote SSH using the same address.

## Volumes

| Volume | Purpose |
|--------|---------|
| `~/dev` → `/home/ubuntu/dev` | Your repos (bind mount) |
| `~/.ssh/id_ed25519.pub` | SSH authorized keys |
| `devbox-history` | Persistent bash history |
| `vscode-server` | Persistent VS Code server extensions |

## Notes

- The container runs `sshd` on port 2222 (host networking).
- SSH key: place your public key at `~/.ssh/id_ed25519.pub` on the host before starting.
- Git credentials: `.gitconfig` is intentionally not bind-mounted so the container can save its own git credentials via `gh auth login`.
- `DOTNET_CLI_TELEMETRY_OPTOUT` and `DOTNET_NOLOGO` are set to suppress .NET telemetry and logo output.
