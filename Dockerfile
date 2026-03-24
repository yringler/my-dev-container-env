# =============================================================================
# Polyglot Dev Container
# C# (.NET), Node/TypeScript, Dart/Flutter, Go, Rust, Hugo
# Base: Ubuntu 24.04 LTS
# =============================================================================

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/New_York

# -----------------------------------------------------------------------------
# Version pins — bump these to upgrade
# -----------------------------------------------------------------------------
ENV NODE_VERSION=24
ENV GO_VERSION=1.23.4
ENV HUGO_VERSION=0.159.0
ENV FLUTTER_VERSION=3.27.1

# -----------------------------------------------------------------------------
# Create dev user
# UID/GID passed from docker-compose via build args — matches your host user
# so bind-mounted files have correct ownership
# -----------------------------------------------------------------------------
ARG DEV_UID=1000
ARG DEV_GID=1000
ARG DEV_USER=dev

RUN groupadd -g $DEV_GID $DEV_USER \
    && useradd -m -u $DEV_UID -g $DEV_GID -s /bin/bash $DEV_USER

# -----------------------------------------------------------------------------
# System packages (root)
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    # Core utilities
    curl wget git unzip zip tar xz-utils \
    # Build tools
    build-essential cmake pkg-config \
    # SSL / crypto
    ca-certificates gnupg libssl-dev \
    # Compression
    zstd \
    # Shells
    bash zsh fish \
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
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# .NET SDK (root)
# -----------------------------------------------------------------------------
RUN wget https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb \
        -O /tmp/packages-microsoft-prod.deb \
    && dpkg -i /tmp/packages-microsoft-prod.deb \
    && rm /tmp/packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y dotnet-sdk-8.0 dotnet-sdk-9.0 \
    && rm -rf /var/lib/apt/lists/*

ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV DOTNET_NOLOGO=1

# -----------------------------------------------------------------------------
# Node.js (root) — system-wide via NodeSource
# This is the default Node. fnm handles per-project overrides if needed.
# -----------------------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Go (root)
# -----------------------------------------------------------------------------
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
    | tar -C /usr/local -xzf -

ENV PATH="/usr/local/go/bin:$PATH"

# -----------------------------------------------------------------------------
# Hugo (root)
# -----------------------------------------------------------------------------
RUN curl -fsSL "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.deb" \
    -o /tmp/hugo.deb \
    && dpkg -i /tmp/hugo.deb \
    && rm /tmp/hugo.deb

# =============================================================================
# Switch to dev user — everything below installs into ~/.cargo, ~/go, etc.
# =============================================================================
USER $DEV_USER
ENV HOME=/home/$DEV_USER

# -----------------------------------------------------------------------------
# Global npm packages + fnm (dev user)
# fnm installs to ~/.local/share/fnm and shims to ~/.local/share/fnm/aliases
# -----------------------------------------------------------------------------
RUN npm install -g \
        typescript \
        ts-node \
        tsx \
        pnpm \
        yarn \
        @angular/cli \
        prettier \
        eslint \
        fnm

# -----------------------------------------------------------------------------
# Rust (dev user)
# -----------------------------------------------------------------------------
ENV RUSTUP_HOME=$HOME/.rustup
ENV CARGO_HOME=$HOME/.cargo
ENV PATH="$HOME/.cargo/bin:$PATH"

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable --no-modify-path \
    && rustup component add \
        clippy \
        rustfmt \
        rust-analyzer \
    && cargo install \
        cargo-watch \
        cargo-edit \
        cargo-nextest

# -----------------------------------------------------------------------------
# Go tools (dev user)
# -----------------------------------------------------------------------------
ENV GOPATH=$HOME/go
ENV PATH="$GOPATH/bin:$PATH"

RUN go install golang.org/x/tools/gopls@latest \
    && go install github.com/go-delve/delve/cmd/dlv@latest \
    && go install honnef.co/go/tools/cmd/staticcheck@latest

# -----------------------------------------------------------------------------
# Flutter (dev user)
# -----------------------------------------------------------------------------
ENV FLUTTER_HOME=$HOME/flutter
ENV PATH="$FLUTTER_HOME/bin:$PATH"

RUN git clone --depth 1 --branch $FLUTTER_VERSION \
    https://github.com/flutter/flutter.git $FLUTTER_HOME \
    && flutter precache --no-ios --no-macos --no-windows \
    && flutter config --no-analytics

# -----------------------------------------------------------------------------
# Shell profile
# -----------------------------------------------------------------------------
RUN echo '' >> ~/.bashrc \
    && echo '# Go' >> ~/.bashrc \
    && echo 'export GOPATH=$HOME/go' >> ~/.bashrc \
    && echo 'export PATH="$GOPATH/bin:$PATH"' >> ~/.bashrc \
    && echo '' >> ~/.bashrc \
    && echo '# fnm (per-project Node version switching)' >> ~/.bashrc \
    && echo 'eval "$(fnm env --use-on-cd)"' >> ~/.bashrc

# -----------------------------------------------------------------------------
# Working directory
# -----------------------------------------------------------------------------
WORKDIR /workspaces

CMD ["/bin/bash"]