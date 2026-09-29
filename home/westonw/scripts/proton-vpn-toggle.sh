#!/usr/bin/env bash
set -euo pipefail

app_config="${XDG_CONFIG_HOME:-$HOME/.config}/Proton/VPN/app-config.json"

if hyprctl clients -j \
  | jq -e '.[] | select(.class == "proton.vpn.app.gtk")' >/dev/null; then
  hyprctl dispatch 'hl.dsp.workspace.toggle_special("vpn")'
  exit
fi

if [ -f "$app_config" ]; then
  temporary=$(mktemp "$app_config.XXXXXX")
  trap 'rm -f "$temporary"' EXIT
  jq '.start_app_minimized = false' "$app_config" > "$temporary"
  mv "$temporary" "$app_config"
fi
# Proton 4.14 can keep a tray-only process that cannot recreate its window.
pkill -9 -f '/bin/.protonvpn-app-wrapped' 2>/dev/null || true
protonvpn-app >/dev/null 2>&1 &

for _ in $(seq 1 50); do
  if hyprctl clients -j \
    | jq -e '.[] | select(.class == "proton.vpn.app.gtk")' >/dev/null; then
    hyprctl dispatch 'hl.dsp.workspace.toggle_special("vpn")'
    exit
  fi
  sleep 0.1
done
