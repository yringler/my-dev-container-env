# =============================================================================
# Polyglot Dev Container
# C# (.NET), Node/TypeScript, Dart/Flutter, Go, Rust
# Base: Ubuntu 24.04 LTS
# =============================================================================

FROM ubuntu:24.04

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/New_York

# -----------------------------------------------------------------------------
# System base packages
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
    # Shell
    bash zsh fish \
    # Editor essentials
    vim nano \
    # Network tools
    iputils-ping dnsutils \
    # Process tools
    htop tree jq \
    # Python (needed by some toolchains)
    python3 python3-pip \
    # Font support (Flutter)
    libglib2.0-dev libgtk-3-dev \
    # Suggested for flutter
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# .NET SDK (latest LTS — currently 8, plus 9)
# https://learn.microsoft.com/en-us/dotnet/core/install/linux-ubuntu
# -----------------------------------------------------------------------------
RUN wget https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb \
    && dpkg -i /tmp/packages-microsoft-prod.deb \
    && rm /tmp/packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y dotnet-sdk-8.0 dotnet-sdk-9.0 \
    && rm -rf /var/lib/apt/lists/*

ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV DOTNET_NOLOGO=1

# -----------------------------------------------------------------------------
# Node.js — via nvm (allows multiple versions)
# -----------------------------------------------------------------------------
ENV NVM_DIR=/root/.nvm
ENV NODE_VERSION=24.14.0

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default \
    # Global packages
    && npm install -g \
        typescript \
        ts-node \
        tsx \
        pnpm \
        yarn \
        @angular/cli \
        prettier \
        eslint 

# Make node/npm available without sourcing nvm manually
ENV PATH="$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH"

# -----------------------------------------------------------------------------
# Go
# https://go.dev/dl/
# -----------------------------------------------------------------------------
ENV GO_VERSION=1.26.1

RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
    | tar -C /usr/local -xzf -

ENV GOPATH=/root/go
ENV PATH="/usr/local/go/bin:$GOPATH/bin:$PATH"

# Common Go tools
RUN go install golang.org/x/tools/gopls@latest \
    && go install github.com/go-delve/delve/cmd/dlv@latest \
    && go install honnef.co/go/tools/cmd/staticcheck@latest

# -----------------------------------------------------------------------------
# Hugo
# -----------------------------------------------------------------------------
ENV HUGO_VERSION=0.159.0
RUN curl -fsSL "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.deb" \
    -o /tmp/hugo.deb \
    && dpkg -i /tmp/hugo.deb \
    && rm /tmp/hugo.deb

# -----------------------------------------------------------------------------
# Rust — via rustup
# -----------------------------------------------------------------------------
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable

ENV PATH="/root/.cargo/bin:$PATH"

# Common Rust components & tools
RUN rustup component add \
        clippy \
        rustfmt \
        rust-analyzer \
    && cargo install \
        cargo-watch \
        cargo-edit \
        cargo-nextest

# -----------------------------------------------------------------------------
# Dart & Flutter
# -----------------------------------------------------------------------------
ENV FLUTTER_VERSION=3.41.5

# Flutter SDK
RUN git clone --depth 1 --branch $FLUTTER_VERSION \
    https://github.com/flutter/flutter.git /opt/flutter \
    && /opt/flutter/bin/flutter precache --no-ios --no-macos --no-windows \
    && /opt/flutter/bin/flutter config --no-analytics

ENV PATH="/opt/flutter/bin:$PATH"

# -----------------------------------------------------------------------------
# Shell config — make all toolchains available in interactive shells
# -----------------------------------------------------------------------------
RUN echo '\n# nvm' >> /root/.bashrc \
    && echo 'export NVM_DIR="/root/.nvm"' >> /root/.bashrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /root/.bashrc \
    && echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> /root/.bashrc

# -----------------------------------------------------------------------------
# Working directory — repos will be mounted here
# -----------------------------------------------------------------------------
WORKDIR /workspaces

CMD ["/bin/bash"]
