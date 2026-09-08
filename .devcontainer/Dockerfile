FROM debian:bookworm-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

# Install system dependencies, including those needed to build Erlang with mise.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      autoconf \
      build-essential \
      ca-certificates \
      curl \
      git \
      inotify-tools \
      libncurses-dev \
      libsctp-dev \
      libssl-dev \
      openssh-client \
      pkg-config \
      postgresql-client \
      sudo \
      unzip \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    MIX_HOME=/home/${USERNAME}/.mix \
    HEX_HOME=/home/${USERNAME}/.hex \
    PATH=/home/${USERNAME}/.local/share/mise/shims:/home/${USERNAME}/.local/bin:/home/${USERNAME}/.opencode/bin:${PATH}

USER ${USERNAME}

RUN curl -fsSL https://mise.run | sh \
    && mise --version \
    && echo 'eval "$(mise activate bash)"' >> ~/.bashrc

RUN curl -fsSL https://chatgpt.com/codex/install.sh | sh \
    && codex --version \
    && curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path \
    && opencode --version

WORKDIR /workspaces/flight_log

CMD ["sleep", "infinity"]
