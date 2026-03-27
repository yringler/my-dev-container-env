# =============================================================================
# Polyglot Dev Container
# C# (.NET), Node/TypeScript, Dart/Flutter, Go, Rust, Hugo
# Base: Ubuntu 24.04 LTS
# Uses the built-in 'ubuntu' user (UID 1000)
# =============================================================================

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/New_York

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
# Go (root) — extracts to /usr/local/go, available to all users
# -----------------------------------------------------------------------------
ENV GO_VERSION=1.26.0
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
    | tar -C /usr/local -xzf -

ENV PATH="/usr/local/go/bin:$PATH"

# -----------------------------------------------------------------------------
# Hugo (root) — .deb installs to /usr/local/bin, available to all users
# -----------------------------------------------------------------------------
ENV HUGO_VERSION=0.159.0
RUN curl -fsSL "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.deb" \
    -o /tmp/hugo.deb \
    && dpkg -i /tmp/hugo.deb \
    && rm /tmp/hugo.deb

# =============================================================================
# Switch to ubuntu user (UID 1000, already exists in base image)
# Everything below installs into /home/ubuntu/
# =============================================================================
USER ubuntu
ENV HOME=/home/ubuntu
ENV LOCAL=$HOME/opt

# -----------------------------------------------------------------------------
# Node.js — installed locally via fnm into ~/opt/fnm
# fnm manages Node versions entirely in user space, no root needed
# -----------------------------------------------------------------------------
ENV FNM_DIR=$LOCAL/fnm
ENV NODE_VERSION=24
ENV PATH="$FNM_DIR/aliases/default/bin:$PATH"

RUN curl -fsSL https://fnm.vercel.app/install \
        | bash -s -- --install-dir $FNM_DIR --skip-shell \
    && $FNM_DIR/fnm install $NODE_VERSION \
    && $FNM_DIR/fnm alias $NODE_VERSION default \
    && $FNM_DIR/fnm default $NODE_VERSION

# Global npm packages — installed into fnm's default Node
RUN npm install -g \
        typescript \
        ts-node \
        tsx \
        pnpm \
        yarn \
        @angular/cli \
        prettier \
        eslint

# -----------------------------------------------------------------------------
# .NET SDK — installs to ~/.dotnet by default
# -----------------------------------------------------------------------------
ENV DOTNET_ROOT=$HOME/.dotnet
ENV PATH="$DOTNET_ROOT:$DOTNET_ROOT/tools:$PATH"
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV DOTNET_NOLOGO=1

RUN curl -fsSL https://dot.net/v1/dotnet-install.sh \
    | bash -s -- --channel LTS


# -----------------------------------------------------------------------------
# Go tools — installs to ~/go/bin
# -----------------------------------------------------------------------------
ENV GOPATH=$HOME/go
ENV PATH="$GOPATH/bin:$PATH"

RUN go install golang.org/x/tools/gopls@latest \
    && go install github.com/go-delve/delve/cmd/dlv@latest \
    && go install honnef.co/go/tools/cmd/staticcheck@latest

# -----------------------------------------------------------------------------
# Flutter — cloned to ~/opt/flutter
# -----------------------------------------------------------------------------
ENV FLUTTER_VERSION=3.27.1
ENV FLUTTER_HOME=$LOCAL/flutter
ENV PATH="$FLUTTER_HOME/bin:$PATH"

RUN git clone --depth 1 --branch $FLUTTER_VERSION \
    https://github.com/flutter/flutter.git $FLUTTER_HOME \
    && flutter precache --no-ios --no-macos --no-windows \
    && flutter config --no-analytics

# -----------------------------------------------------------------------------
# Shell profile
# -----------------------------------------------------------------------------
RUN echo '' >> ~/.bashrc \
    && echo '# local opt' >> ~/.bashrc \
    && echo 'export LOCAL=$HOME/opt' >> ~/.bashrc \
    && echo '' >> ~/.bashrc \
    && echo '# fnm' >> ~/.bashrc \
    && echo 'export FNM_DIR=$LOCAL/fnm' >> ~/.bashrc \
    && echo 'eval "$($FNM_DIR/fnm env --use-on-cd)"' >> ~/.bashrc \
    && echo '' >> ~/.bashrc \
    && echo '# dotnet' >> ~/.bashrc \
    && echo 'export DOTNET_ROOT=$HOME/.dotnet' >> ~/.bashrc \
    && echo 'export PATH="$DOTNET_ROOT:$DOTNET_ROOT/tools:$PATH"' >> ~/.bashrc \
    && echo '' >> ~/.bashrc \
    && echo '# Go' >> ~/.bashrc \
    && echo 'export GOPATH=$HOME/go' >> ~/.bashrc \
    && echo 'export PATH="$GOPATH/bin:$PATH"' >> ~/.bashrc \
    && echo '' >> ~/.bashrc \
    && echo '# Flutter' >> ~/.bashrc \
    && echo 'export PATH="$LOCAL/flutter/bin:$PATH"' >> ~/.bashrc

# -----------------------------------------------------------------------------
# Working directory
# -----------------------------------------------------------------------------
WORKDIR /workspaces

USER root
RUN apt-get update && apt-get install -y openssh-server \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /run/sshd \
    && ssh-keygen -A

USER ubuntu
#RUN mkdir -p ~/.ssh && chmod 700 ~/.ssh
# You'll COPY or mount your public key here:
#COPY --chown=ubuntu:ubuntu id_rsa.pub /home/ubuntu/.ssh/id_rsa.pub


EXPOSE 22

# Switch back to root to start sshd (it requires root to bind port 22)
USER root
COPY entrypoint.sh /entrypoint.sh
#CMD ["/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D"]