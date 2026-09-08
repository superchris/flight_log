ARG ELIXIR_VERSION=1.16.2
ARG OTP_VERSION=26.2.1
ARG DEBIAN_VERSION=bookworm-20240130-slim

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

# Install system dependencies.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      ca-certificates \
      curl \
      git \
      inotify-tools \
      openssh-client \
      postgresql-client \
      sudo \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

ENV MIX_HOME=/home/${USERNAME}/.mix \
    HEX_HOME=/home/${USERNAME}/.hex \
    PATH=/home/${USERNAME}/.local/bin:/home/${USERNAME}/.opencode/bin:${PATH}

USER ${USERNAME}

RUN curl -fsSL https://chatgpt.com/codex/install.sh | sh \
    && codex --version \
    && curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path \
    && opencode --version \
    && mix local.hex --force \
    && mix local.rebar --force

WORKDIR /workspaces/flight_log

CMD ["sleep", "infinity"]
