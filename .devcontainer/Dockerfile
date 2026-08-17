ARG ELIXIR_VERSION=1.16.2
ARG OTP_VERSION=26.2.1
ARG DEBIAN_VERSION=bullseye-20240130-slim

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      curl \
      git \
      inotify-tools \
      openssh-client \
      postgresql-client \
      sudo \
    && groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV MIX_HOME=/home/${USERNAME}/.mix \
    HEX_HOME=/home/${USERNAME}/.hex \
    PATH=/home/${USERNAME}/.opencode/bin:${PATH}

USER ${USERNAME}

RUN curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path \
    && opencode --version \
    && mix local.hex --force \
    && mix local.rebar --force

WORKDIR /workspaces/flight_log

CMD ["sleep", "infinity"]
