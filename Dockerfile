# =============================================================================
# Polyglot Dev Container
# C# (.NET), Node/TypeScript, Dart/Flutter, Go, Rust, Hugo
# Base: Debian 12 Slim
#
# Design decisions:
#   - All toolchains install to /opt or /usr/local (root filesystem),
#     keeping $HOME clean so it can be a persistent volume.
#   - Non-root user 'dev' (UID 1000) for bind-mount compatibility.
#   - Layers ordered slow-changing (system, Go, Rust) → fast-changing
#     (Node packages, Flutter, dotnet) for cache efficiency.
# =============================================================================

FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/New_York

# -----------------------------------------------------------------------------
# 1. System packages (changes rarely)
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core utilities
    curl wget git unzip zip tar xz-utils ca-certificates gnupg \
    # Build tools
    build-essential cmake pkg-config libssl-dev \
    # Compression
    zstd \
    # Shells
    bash zsh \
    # Editors
    vim nano \
    # Network
    iputils-ping dnsutils \
    # Process / inspect
    htop tree jq \
    # Python (needed by some toolchains)
    python3 python3-pip \
    # Flutter Linux desktop dependencies
    libglib2.0-dev libgtk-3-dev libglu1-mesa \
    # SSH server (for Zed remote)
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 2. Go — /usr/local/go (changes rarely)
# -----------------------------------------------------------------------------
ENV GO_VERSION=1.23.4
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
    | tar -C /usr/local -xzf -

ENV PATH="/usr/local/go/bin:$PATH"
ENV GOPATH=/opt/go
ENV PATH="$GOPATH/bin:$PATH"

RUN go install golang.org/x/tools/gopls@latest \
    && go install github.com/go-delve/delve/cmd/dlv@latest \
    && go install honnef.co/go/tools/cmd/staticcheck@latest

# -----------------------------------------------------------------------------
# 3. Rust — /opt/rust (changes rarely)
# -----------------------------------------------------------------------------
ENV RUSTUP_HOME=/opt/rust/rustup
ENV CARGO_HOME=/opt/rust/cargo
ENV PATH="/opt/rust/cargo/bin:$PATH"

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable --no-modify-path \
    && rustup component add clippy rustfmt rust-analyzer \
    && cargo install cargo-watch cargo-edit cargo-nextest

# -----------------------------------------------------------------------------
# 4. Hugo — /usr/local/bin (changes rarely)
# -----------------------------------------------------------------------------
ENV HUGO_VERSION=0.159.0
RUN curl -fsSL "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.deb" \
    -o /tmp/hugo.deb \
    && dpkg -i /tmp/hugo.deb \
    && rm /tmp/hugo.deb

# -----------------------------------------------------------------------------
# 5. .NET SDK — /opt/dotnet (changes moderately)
# -----------------------------------------------------------------------------
ENV DOTNET_ROOT=/opt/dotnet
ENV PATH="$DOTNET_ROOT:$DOTNET_ROOT/tools:$PATH"
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV DOTNET_NOLOGO=1

RUN curl -fsSL https://dot.net/v1/dotnet-install.sh \
    | bash -s -- --channel LTS --install-dir $DOTNET_ROOT

# -----------------------------------------------------------------------------
# 6. Node.js via fnm — /opt/fnm (changes moderately)
# -----------------------------------------------------------------------------
ENV FNM_DIR=/opt/fnm
ENV NODE_VERSION=24
ENV PATH="$FNM_DIR/aliases/default/bin:$PATH"

RUN curl -fsSL https://fnm.vercel.app/install \
        | bash -s -- --install-dir $FNM_DIR --skip-shell \
    && $FNM_DIR/fnm install $NODE_VERSION \
    && $FNM_DIR/fnm alias $NODE_VERSION default \
    && $FNM_DIR/fnm default $NODE_VERSION

# 7. Global npm packages (changes most often among Node layers)
RUN npm install -g \
        typescript ts-node tsx \
        pnpm yarn \
        @angular/cli \
        prettier eslint

# -----------------------------------------------------------------------------
# 8. Flutter — /opt/flutter (changes moderately)
# -----------------------------------------------------------------------------
ENV FLUTTER_VERSION=3.27.1
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="$FLUTTER_HOME/bin:$PATH"

RUN git clone --depth 1 --branch $FLUTTER_VERSION \
        https://github.com/flutter/flutter.git $FLUTTER_HOME \
    && flutter precache --no-ios --no-macos --no-windows \
    && flutter config --no-analytics

# -----------------------------------------------------------------------------
# 9. Non-root user (changes rarely, but depends on everything above)
# -----------------------------------------------------------------------------
RUN groupadd -g 1000 dev \
    && useradd -u 1000 -g dev -m -s /bin/bash dev \
    && chmod -R a+rX /opt

USER dev
ENV HOME=/home/dev

# Shell profile — only runtime env, no installed software lives here
RUN { \
    echo ''; \
    echo '# fnm'; \
    echo 'eval "$(/opt/fnm/fnm env --use-on-cd)"'; \
    echo ''; \
    echo '# dotnet'; \
    echo 'export DOTNET_ROOT=/opt/dotnet'; \
    echo 'export PATH="$DOTNET_ROOT:$DOTNET_ROOT/tools:$PATH"'; \
    echo ''; \
    echo '# Go'; \
    echo 'export GOPATH=/opt/go'; \
    echo 'export PATH="$GOPATH/bin:$PATH"'; \
    echo ''; \
    echo '# Rust'; \
    echo 'export RUSTUP_HOME=/opt/rust/rustup'; \
    echo 'export CARGO_HOME=/opt/rust/cargo'; \
    echo 'export PATH="/opt/rust/cargo/bin:$PATH"'; \
    echo ''; \
    echo '# Flutter'; \
    echo 'export PATH="/opt/flutter/bin:$PATH"'; \
} >> ~/.bashrc

WORKDIR /workspaces

# -----------------------------------------------------------------------------
# 10. SSH server — runs as root, serves dev user (for Zed remote)
# -----------------------------------------------------------------------------
USER root
RUN mkdir -p /run/sshd \
    && ssh-keygen -A \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

EXPOSE 2222

CMD ["/usr/sbin/sshd", "-D", "-p", "2222", "-e"]
