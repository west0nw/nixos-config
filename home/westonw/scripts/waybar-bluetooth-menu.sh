#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

btctl="bluetoothctl"
wofi="wofi"
wofi() { command wofi --define allow_markup=false "$@"; }

truncate_text() {
  local text="$1"
  local max="$2"
  if (( ${#text} > max )); then
    printf "%s…" "${text:0:max-1}"
  else
    printf "%s" "$text"
  fi
}

bt_row() {
  local connected_marker="$1"
  local icon="$2"
  local name="$3"
  local name_short

  name_short="$(truncate_text "$name" 34)"
  printf "%s %s  %-36s" "$connected_marker" "$icon" "$name_short"
}

if [[ "${1:-}" == "--status" ]]; then
  powered="$($btctl show 2>/dev/null | awk '/Powered:/ {print $2}')"
  if [[ "$powered" != "yes" ]]; then
    printf "󰂲 off\n"
    exit 0
  fi

  first_connected="$($btctl devices Connected 2>/dev/null | awk 'NR==1{$1="";$2="";sub(/^  */, ""); print; exit}')"
  if [[ -n "$first_connected" ]]; then
    printf "󰂱 %s\n" "$first_connected"
  else
    printf "󰂯 on\n"
  fi
  exit 0
fi

declare -A mac_by_key
entries=()

powered="$($btctl show 2>/dev/null | awk '/Powered:/ {print $2}')"
if [[ "$powered" == "yes" ]]; then
  entries+=("A|󰂲  Turn Bluetooth off")
  entries+=("B|󰐍  Scan and pair new device")
else
  entries+=("A|󰂯  Turn Bluetooth on")
fi

i=1
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  mac="$(printf '%s\n' "$line" | awk '{print $2}')"
  name="$(printf '%s\n' "$line" | awk '{$1="";$2="";sub(/^  */, ""); print}')"
  info="$($btctl info "$mac" 2>/dev/null || true)"
  connected="$(printf '%s\n' "$info" | awk '/Connected:/ {print $2}')"

  key="D$i"
  if [[ "$connected" == "yes" ]]; then
    entries+=("$key|$(bt_row "●" "󰂱" "$name")")
  else
    entries+=("$key|$(bt_row " " "󰂯" "$name")")
  fi
  mac_by_key["$key"]="$mac"
  i=$((i + 1))
done < <($btctl devices Paired 2>/dev/null)

choice="$(printf '%s\n' "${entries[@]}" | $wofi --dmenu --prompt 'Bluetooth')" || exit 0
key="${choice%%|*}"

case "$key" in
  A)
    if [[ "$powered" == "yes" ]]; then
      $btctl power off >/dev/null 2>&1 || true
    else
      rfkill unblock bluetooth
      $btctl power on
    fi
    ;;
  B)
    rfkill unblock bluetooth
    $btctl power on
    timeout 8 $btctl scan on >/dev/null 2>&1 || true

    declare -A scan_mac_by_key
    scan_entries=()
    j=1
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      mac="$(printf '%s\n' "$line" | awk '{print $2}')"
      name="$(printf '%s\n' "$line" | awk '{$1="";$2="";sub(/^  */, ""); print}')"
      scan_key="S$j"
      scan_entries+=("$scan_key|$(bt_row " " "󰂯" "$name")")
      scan_mac_by_key["$scan_key"]="$mac"
      j=$((j + 1))
    done < <($btctl devices 2>/dev/null)

    scan_choice="$(printf '%s\n' "${scan_entries[@]}" | $wofi --dmenu --prompt 'Pair device')" || exit 0
    scan_key="${scan_choice%%|*}"
    mac="${scan_mac_by_key[$scan_key]:-}"
    [[ -z "$mac" ]] && exit 0

    $btctl pair "$mac" >/dev/null 2>&1 || true
    $btctl trust "$mac" >/dev/null 2>&1 || true
    $btctl connect "$mac" >/dev/null 2>&1 || true
    ;;
  D*)
    mac="${mac_by_key[$key]:-}"
    [[ -z "$mac" ]] && exit 0
    info="$($btctl info "$mac" 2>/dev/null || true)"
    connected="$(printf '%s\n' "$info" | awk '/Connected:/ {print $2}')"
    trusted="$(printf '%s\n' "$info" | awk '/Trusted:/ {print $2}')"

    actions=()
    if [[ "$connected" == "yes" ]]; then
      actions+=("1|󰂲  Disconnect")
    else
      actions+=("1|󰂱  Connect")
    fi
    if [[ "$trusted" == "yes" ]]; then
      actions+=("2|󰌾  Untrust")
    else
      actions+=("2|󰌾  Trust")
    fi
    actions+=("3|󰆴  Forget device")

    action_choice="$(printf '%s\n' "${actions[@]}" | $wofi --dmenu --prompt 'Device action')" || exit 0
    action_key="${action_choice%%|*}"

    case "$action_key" in
      1)
        if [[ "$connected" == "yes" ]]; then
          $btctl disconnect "$mac" >/dev/null 2>&1 || true
        else
          $btctl connect "$mac" >/dev/null 2>&1 || true
        fi
        ;;
      2)
        if [[ "$trusted" == "yes" ]]; then
          $btctl untrust "$mac" >/dev/null 2>&1 || true
        else
          $btctl trust "$mac" >/dev/null 2>&1 || true
        fi
        ;;
      3)
        $btctl remove "$mac" >/dev/null 2>&1 || true
        ;;
    esac
    ;;
esac
