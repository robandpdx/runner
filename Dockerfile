# This Dockerfile is based on https://github.com/actions/runner/blob/main/images/Dockerfile
FROM ubuntu:24.04

ARG TARGETOS
ARG TARGETARCH
ARG UBUNTU_VERSION="24.04"
ARG RUNNER_VERSION="2.331.0"
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.7.0
ARG DOCKER_VERSION=29.2.0
ARG BUILDX_VERSION=0.31.1
ARG NODE_VERSIONS="18 19 20 21 22 23 24 25"
ARG DEFAULT_NODE_MAJOR="24"
ARG PYTHON_VERSIONS="3.10 3.11 3.12 3.13 3.14"
ARG UV_VERSION="0.10.9"

# Add packages to the list below as needed.
RUN apt update -y && apt install sudo \
                            lsb-release \
                            gpg-agent \
                            software-properties-common \
                            curl \
                            xz-utils \
                            unzip \
                            wget \
                            dpkg \
                            ssh \
                            jq \
                            git \
                            git-lfs \
                            libyaml-dev \
                            build-essential \
                            libncurses5-dev \
                            libsqlite3-dev \
                            libicu-dev -y --no-install-recommends
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=${TARGETARCH} signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt update \
    && apt install gh -y \
    && rm -rf /var/lib/apt/lists/*


WORKDIR /home/runner

RUN wget https://packages.microsoft.com/config/ubuntu/${UBUNTU_VERSION}/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb
RUN rm packages-microsoft-prod.deb
RUN apt-get update && apt-get install -y aspnetcore-runtime-8.0

RUN export RUNNER_ARCH=${TARGETARCH} \
    && if [ "$RUNNER_ARCH" = "amd64" ]; then export RUNNER_ARCH=x64 ; fi \
    && curl -f -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-${TARGETOS}-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz

RUN curl -f -L -o runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip \
    && unzip ./runner-container-hooks.zip -d ./k8s \
    && rm runner-container-hooks.zip

RUN curl -f -L -o runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v0.8.1/actions-runner-hooks-k8s-0.8.1.zip \
    && unzip ./runner-container-hooks.zip -d ./k8s-novolume \
    && rm runner-container-hooks.zip

RUN export RUNNER_ARCH=${TARGETARCH} \
    && if [ "$RUNNER_ARCH" = "amd64" ]; then export DOCKER_ARCH=x86_64 ; fi \
    && if [ "$RUNNER_ARCH" = "arm64" ]; then export DOCKER_ARCH=aarch64 ; fi \
    && curl -fLo docker.tgz https://download.docker.com/${TARGETOS}/static/stable/${DOCKER_ARCH}/docker-${DOCKER_VERSION}.tgz \
    && tar zxvf docker.tgz \
    && rm -rf docker.tgz \
    && mkdir -p /usr/local/lib/docker/cli-plugins \
    && curl -fLo /usr/local/lib/docker/cli-plugins/docker-buildx \
        "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-${TARGETARCH}" \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

# Install listed Node.js major versions (latest patch per major)
RUN export RUNNER_ARCH=${TARGETARCH} \
    && if [ "$RUNNER_ARCH" = "amd64" ]; then export RUNNER_ARCH=x64 ; fi \
        && mkdir -p /opt/hostedtoolcache/node \
        && curl -fsSL https://nodejs.org/dist/index.json -o /tmp/node-index.json \
        && for NODE_MAJOR in ${NODE_VERSIONS}; do \
                NODE_VERSION=$(jq -r --arg prefix "${NODE_MAJOR}." '[.[] | .version | ltrimstr("v") | select(startswith($prefix))][0]' /tmp/node-index.json); \
                if [ -z "$NODE_VERSION" ] || [ "$NODE_VERSION" = "null" ]; then echo "Unable to resolve Node.js major ${NODE_MAJOR}"; exit 1; fi; \
                mkdir -p "/opt/hostedtoolcache/node/${NODE_VERSION}/${RUNNER_ARCH}"; \
                curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${RUNNER_ARCH}.tar.xz" \
                    | tar -xJ --strip-components=1 -C "/opt/hostedtoolcache/node/${NODE_VERSION}/${RUNNER_ARCH}"; \
                touch "/opt/hostedtoolcache/node/${NODE_VERSION}/${RUNNER_ARCH}.complete"; \
        done \
        && rm -f /tmp/node-index.json

# Set default Node.js and make corepack available
RUN export RUNNER_ARCH=${TARGETARCH} \
    && if [ "$RUNNER_ARCH" = "amd64" ]; then export RUNNER_ARCH=x64 ; fi \
    && NODE_FOR_DEFAULT=$(ls -1 /opt/hostedtoolcache/node | sort -V | grep -E "^${DEFAULT_NODE_MAJOR}\." | tail -n 1) \
    && test -n "$NODE_FOR_DEFAULT" \
    && NODE_BIN_DIR="/opt/hostedtoolcache/node/${NODE_FOR_DEFAULT}/${RUNNER_ARCH}/bin" \
    && test -x "$NODE_BIN_DIR/node" \
    && ln -sf "$NODE_BIN_DIR/node" /usr/local/bin/node \
    && ln -sf "$NODE_BIN_DIR/npm" /usr/local/bin/npm \
    && ln -sf "$NODE_BIN_DIR/npx" /usr/local/bin/npx \
    && test -x "$NODE_BIN_DIR/corepack" \
    && ln -sf "$NODE_BIN_DIR/corepack" /usr/local/bin/corepack \
    && corepack --version

# Install uv into tool cache
RUN export UV_ARCH=${TARGETARCH} \
        && if [ "$UV_ARCH" = "amd64" ]; then export UV_ARCH=x86_64 ; fi \
        && if [ "$UV_ARCH" = "arm64" ]; then export UV_ARCH=aarch64 ; fi \
        && export UV_PLATFORM=unknown-linux-gnu \
        && mkdir -p "/opt/hostedtoolcache/uv/${UV_VERSION}/${UV_ARCH}" \
        && curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${UV_ARCH}-${UV_PLATFORM}.tar.gz" \
            | tar -xz --strip-components=1 -C "/opt/hostedtoolcache/uv/${UV_VERSION}/${UV_ARCH}" "uv-${UV_ARCH}-${UV_PLATFORM}" \
        && touch "/opt/hostedtoolcache/uv/${UV_VERSION}/${UV_ARCH}.complete"

# Install Python versions into tool cache
RUN export RUNNER_ARCH=${TARGETARCH} \
    && if [ "$RUNNER_ARCH" = "amd64" ]; then export RUNNER_ARCH=x64 ; fi \
    && export UV_BIN=$(find /opt/hostedtoolcache/uv -type f -name uv | head -n 1) \
    && test -n "$UV_BIN" \
    && mkdir -p /opt/hostedtoolcache/Python \
    && for PYTHON_VERSION in ${PYTHON_VERSIONS}; do \
        "$UV_BIN" python install "$PYTHON_VERSION"; \
        PYTHON_BIN=$("$UV_BIN" python find "$PYTHON_VERSION"); \
        PYTHON_ROOT=$(cd "$(dirname "$PYTHON_BIN")/.." && pwd); \
        FULL_VERSION=$("$PYTHON_BIN" -c "import sys; print('.'.join(map(str, sys.version_info[:3])))"); \
        TARGET_DIR="/opt/hostedtoolcache/Python/${FULL_VERSION}/${RUNNER_ARCH}"; \
        mkdir -p "$TARGET_DIR"; \
        cp -a "${PYTHON_ROOT}/." "$TARGET_DIR/"; \
        if [ ! -x "$TARGET_DIR/bin/python" ] && [ -x "$TARGET_DIR/bin/python3" ]; then ln -sf python3 "$TARGET_DIR/bin/python"; fi; \
        touch "/opt/hostedtoolcache/Python/${FULL_VERSION}/${RUNNER_ARCH}.complete"; \
    done


#FROM mcr.microsoft.com/dotnet/runtime-deps:6.0

ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_MANUALLY_TRAP_SIG=1
ENV ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1
ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache

RUN adduser --disabled-password --gecos "" --uid 1001 runner \
    && groupadd docker --gid 123 \
    && usermod -aG sudo runner \
    && usermod -aG docker runner \
    && echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers \
    && echo "Defaults env_keep += \"DEBIAN_FRONTEND\"" >> /etc/sudoers

RUN chown -R runner: /opt
#WORKDIR /home/runner

#COPY --chown=runner:docker --from=build /actions-runner .
#COPY --from=build /usr/local/lib/docker/cli-plugins/docker-buildx /usr/local/lib/docker/cli-plugins/docker-buildx

RUN install -o root -g root -m 755 docker/* /usr/bin/ && rm -rf docker

USER runner
