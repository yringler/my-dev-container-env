## What this is

A single `Dockerfile` that builds a polyglot dev container with six language toolchains on Debian 12 Slim:

| Toolchain | Version | Install path |
|---|---|---|
| Go | 1.23.4 | `/usr/local/go` |
| Rust | stable | `/opt/rust/{rustup,cargo}` |
| .NET SDK | LTS | `/opt/dotnet` |
| Node.js | 24 (via fnm) | `/opt/fnm` |
| Flutter | 3.27.1 | `/opt/flutter` |
| Hugo | 0.159.0 (extended) | `/usr/local/bin/hugo` |

The container runs as a non-root `dev` user (UID 1000). Everything is installed to the root filesystem (`/opt`, `/usr/local`), and `/home/dev` is intentionally empty so you can mount it as a volume for persistent user state.

---

## Quick start

Build:

```sh
docker build -t polydev .
```

Run with your project bind-mounted:

```sh
docker run -it --rm \
  -v "$PWD":/workspaces/project \
  polydev
```

Persist home directory across runs (shell history, git config, tool caches):

```sh
docker volume create devhome

docker run -it --rm \
  -v devhome:/home/dev \
  -v "$PWD":/workspaces/project \
  polydev
```

---

## Why UID 1000?

The `dev` user is created with UID/GID 1000, which matches the default first user on most Linux hosts. This means files created inside the container via a bind mount (`-v "$PWD":/workspaces/project`) are owned by your host user — no `chown` dance required.

If your host UID is different, override at build time:

```sh
docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t polydev .
```

(You'd need to add corresponding `ARG` lines to the Dockerfile — see [Modifying](#modifying-the-dockerfile) below.)

---

## Why nothing installs to /home?

The home directory is designed to be a mountable volume. If toolchains lived there, a fresh named volume would shadow them and everything would break. By keeping installs in `/opt` and `/usr/local` (baked into the image layers), you get:

- A volume on `/home/dev` for dotfiles, `.bashrc` customizations, shell history, git credentials, IDE settings.
- No conflict between image-level tools and user-level state.
- The ability to `docker volume rm devhome` and get a clean home without rebuilding.

Rust is a special case: `rustup` expects write access to `$RUSTUP_HOME` at runtime (for `rustup update`, adding targets, etc.). It's installed to `/opt/rust/` and the env vars point there, so it works without touching home.

---

## Layer caching strategy

The Dockerfile is ordered from least-frequently-changed to most-frequently-changed:

```
1. apt packages          ← rarely changes
2. Go + Go tools         ← pinned version
3. Rust + cargo installs ← pinned to stable
4. Hugo                  ← pinned version
5. .NET SDK              ← pinned to LTS channel
6. Node (fnm)            ← pinned version
7. npm global packages   ← changes most often
8. Flutter               ← pinned version
9. User creation + shell ← almost never changes
```

If you add or remove an npm global package, only layer 7+ rebuilds. If you bump the Go version, layers 2+ rebuild but layer 1 (the big apt install) is cached.

---

## Included tools

Beyond the six runtimes, the image ships with:

**Go tools**: `gopls` (language server), `dlv` (debugger), `staticcheck` (linter).

**Rust tools**: `clippy`, `rustfmt`, `rust-analyzer` (components), `cargo-watch`, `cargo-edit`, `cargo-nextest` (cargo subcommands).

**Node globals**: `typescript`, `ts-node`, `tsx`, `pnpm`, `yarn`, `@angular/cli`, `prettier`, `eslint`.

**System**: `build-essential`, `cmake`, `git`, `curl`, `jq`, `htop`, `vim`, `nano`, `zsh`, `python3`.

---

## Modifying the Dockerfile

### Bump a version

Each toolchain version is controlled by an `ENV` near the top of its section. Change the value and rebuild:

```dockerfile
ENV GO_VERSION=1.24.0       # was 1.23.4
ENV HUGO_VERSION=0.160.0    # was 0.159.0
ENV FLUTTER_VERSION=3.28.0  # was 3.27.1
ENV NODE_VERSION=24          # major version, fnm resolves latest
```

.NET uses `--channel LTS` so it auto-resolves to the latest LTS release on each build. Pin it explicitly if needed:

```dockerfile
RUN curl -fsSL https://dot.net/v1/dotnet-install.sh \
    | bash -s -- --version 8.0.404 --install-dir $DOTNET_ROOT
```

### Add or remove a global npm package

Edit the `npm install -g` layer (step 7). Because it's near the bottom, this won't invalidate the heavier layers above it.

### Add a new toolchain

Insert a new section **above** the user-creation step (step 9) but **below** the things that change less often than it will. Install to `/opt/<toolname>` and add it to `PATH` via an `ENV` line.

### Change the user UID

To support `ARG`-based UID override:

```dockerfile
ARG UID=1000
ARG GID=1000
RUN groupadd -g $GID dev \
    && useradd -u $UID -g dev -m -s /bin/bash dev \
    && chmod -R a+rX /opt
```

### Remove a toolchain you don't need

Delete its section and remove the corresponding `PATH` and env entries. If removing Flutter, you can also drop the `libglib2.0-dev libgtk-3-dev libglu1-mesa` packages from the apt layer to slim the image further.

---

## Compose example

```yaml
services:
  dev:
    build: .
    volumes:
      - devhome:/home/dev
      - .:/workspaces/project
    working_dir: /workspaces/project
    stdin_open: true
    tty: true

volumes:
  devhome:
```

```sh
docker compose run --rm dev
```

---

## Troubleshooting

**`fnm` not found in interactive shell**: The `.bashrc` runs `eval "$(fnm env ...)"` which sets up fnm's shims. If you're using `sh` instead of `bash`, source the profile manually: `. /home/dev/.bashrc`.

**Permission denied on bind mount**: Your host UID doesn't match 1000. Either rebuild with `--build-arg UID=$(id -u)` or run `docker run --user $(id -u):$(id -g) ...` (some tools may complain about missing home dir entries in this mode).

**Rust can't update/add targets**: Make sure `$RUSTUP_HOME` (`/opt/rust/rustup`) is writable by the `dev` user. The Dockerfile handles this, but if you're layering another image on top, verify ownership.

**Flutter doctor complaints**: The image only precaches Linux desktop and web. iOS/macOS/Windows platforms are excluded. Run `flutter doctor` to see what's available.
