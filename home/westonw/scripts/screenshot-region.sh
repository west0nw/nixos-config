#!/usr/bin/env bash
set -euo pipefail

geometry="$(slurp -d)" || exit 0

# Hyprland keeps slurp's fading layer visible briefly after the process exits.
# Wait beyond the configured fadeLayersOut duration before capturing the region.
sleep 0.2

grim -g "$geometry" - | wl-copy --type image/png
notify-send -a Hyprshot -t 5000 "Screenshot saved" "Image copied to the clipboard"
