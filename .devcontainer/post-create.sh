#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

mise trust mise.toml
mise install

mise exec -- mix local.hex --force
mise exec -- mix local.rebar --force
mise exec -- mix setup
