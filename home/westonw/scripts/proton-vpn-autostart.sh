#!/usr/bin/env bash
set -euo pipefail

app_config="${XDG_CONFIG_HOME:-$HOME/.config}/Proton/VPN/app-config.json"
mkdir -p "$(dirname "$app_config")"

temporary=$(mktemp "$app_config.XXXXXX")
trap 'rm -f "$temporary"' EXIT

if [ -f "$app_config" ]; then
  jq \
    '.connect_at_app_startup = "FASTEST" | .start_app_minimized = true' \
    "$app_config" > "$temporary"
else
  jq -n \
    '{tray_pinned_servers: [], connect_at_app_startup: "FASTEST", start_app_minimized: true}' \
    > "$temporary"
fi
mv "$temporary" "$app_config"

exec protonvpn-app
