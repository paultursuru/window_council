#!/bin/bash
# Installs or updates the plugin in xbar, keeping the generated data (window_council_app/data/).
set -euo pipefail

PLUGINS_PATH="${PLUGINS_PATH:-$HOME/Library/Application Support/xbar/plugins}"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "${PLUGINS_PATH}/window_council_app"
rsync -a --delete --exclude 'data/' "${SOURCE_DIR}/window_council_app/" "${PLUGINS_PATH}/window_council_app/"
cp "${SOURCE_DIR}/window_council.10m.rb" "${PLUGINS_PATH}/window_council.10m.rb"
chmod +x "${PLUGINS_PATH}/window_council.10m.rb"

# Refresh now rather than at the next 10 min tick
open -g 'xbar://app.xbarapp.com/refreshAllPlugins' 2>/dev/null || true
