#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

nmcli="nmcli"
wofi="wofi"

# Network names are plain text, even though the application launcher permits markup.
wofi() { command wofi --define allow_markup=false "$@"; }

signal_icon() {
  local signal="$1"
  [[ "$signal" =~ ^[0-9]+$ ]] || signal=0
  signal=$((10#$signal))
  if (( signal >= 80 )); then
    printf "󰤨"
  elif (( signal >= 60 )); then
    printf "󰤥"
  elif (( signal >= 40 )); then
    printf "󰤢"
  elif (( signal >= 20 )); then
    printf "󰤟"
  else
    printf "󰤯"
  fi
}

network_row() {
  local marker="$1"
  local icon="$2"
  local ssid="$3"
  local signal="$4"
  local lock="$5"
  local ssid_short

  ssid_short="$ssid"
  printf "%s%s  %-30s %3s%%%s" "$marker" "$icon" "$ssid_short" "$signal" "$lock"
}

if [[ "${1:-}" == "--status" ]]; then
  wifi_state="$($nmcli -t -f WIFI general 2>/dev/null || true)"
  if [[ "$wifi_state" == "enabled" ]]; then
    active="$($nmcli -t -f IN-USE,SIGNAL dev wifi list --rescan no 2>/dev/null | awk -F: '$1=="*"{print $2; exit}')"
    if [[ -n "$active" ]]; then
      signal="${active##*:}"
      printf "%s %s%%\n" "$(signal_icon "$signal")" "$signal"
    else
      printf "󰤨 on\n"
    fi
  else
    printf "󰤮 off\n"
  fi
  exit 0
fi

while true; do
  declare -A ssid_by_key=()
  declare -A secure_by_key=()
  declare -A seen_ssids=()
  entries=()
  connected_rows=()
  sortable_rows=()

  wifi_state="$($nmcli -t -f WIFI general 2>/dev/null || true)"
  if [[ "$wifi_state" == "enabled" ]]; then
    entries+=("A|󰖪  Turn Wi-Fi off")
  else
    entries+=("A|󰖩  Turn Wi-Fi on")
  fi
  entries+=("B|󰤭  Disconnect current Wi-Fi")
  entries+=("R|󰑐  Refresh network list")
  entries+=("T|󰆍  Open nmtui")

  i=1
  # Keep the SSID suffix intact: IFS splitting would strip its trailing colon.
  while IFS= read -r scan_row; do
    [[ "$scan_row" == *:*:*:* ]] || continue
    IFS=: read -r active signal security _ <<< "$scan_row"
    ssid="${scan_row#*:*:*:}"
    [[ -z "$ssid" ]] && continue
    [[ "$signal" =~ ^[0-9]+$ ]] || continue
    [[ -z "${seen_ssids[$ssid]:-}" ]] || continue
    seen_ssids["$ssid"]=1
    signal=$((10#$signal))
    key="N$i"
    lock=""
    marker="  "
    row=""

    if [[ "$active" == "yes" || "$active" == "*" ]]; then
      marker="● "
    fi
    if [[ -n "$security" && "$security" != "--" ]]; then
      lock=" 󰌾"
      secure_by_key["$key"]="1"
    else
      lock=""
      secure_by_key["$key"]="0"
    fi

    row="$key|$(network_row "$marker" "$(signal_icon "$signal")" "$ssid" "$signal" "$lock")"
    if [[ "$active" == "yes" || "$active" == "*" ]]; then
      connected_rows+=("$row")
    else
      sortable_rows+=("$(printf '%03d' "$signal")|$row")
    fi

    ssid_by_key["$key"]="$ssid"
    i=$((i + 1))
  done < <($nmcli -t --escape no -f ACTIVE,SIGNAL,SECURITY,SSID dev wifi list --rescan no 2>/dev/null \
    | sort -t: -k1,1r -k2,2nr)

  if (( ${#connected_rows[@]} > 0 )); then
    entries+=("${connected_rows[@]}")
  fi

  if (( ${#sortable_rows[@]} > 0 )); then
    while IFS= read -r sortable; do
      [[ -z "$sortable" ]] && continue
      entries+=("${sortable#*|}")
    done < <(printf '%s\n' "${sortable_rows[@]}" | sort -t'|' -k1,1nr)
  elif [[ "$wifi_state" == "enabled" ]] && (( ${#connected_rows[@]} == 0 )); then
    entries+=("X|󰤫  Scanning... choose Refresh in a moment")
  fi

  # Keep control keys private; selecting a row maps its display text back to its key.
  choice="$(printf '%s\n' "${entries[@]#*|}" | $wofi --dmenu --no-custom-entry --prompt 'Wi-Fi')" || exit 0
  key=""
  for entry in "${entries[@]}"; do
    if [[ "${entry#*|}" == "$choice" ]]; then
      key="${entry%%|*}"
      break
    fi
  done

  case "$key" in
    A)
      if [[ "$wifi_state" == "enabled" ]]; then
        $nmcli radio wifi off >/dev/null 2>&1 || true
      else
        $nmcli radio wifi on >/dev/null 2>&1 || true
      fi
      ;;
    B)
      device="$($nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | awk -F: '$2=="wifi" && $3=="connected"{print $1; exit}')"
      if [[ -n "$device" ]]; then
        $nmcli dev disconnect "$device" >/dev/null 2>&1 || true
      fi
      ;;
    R)
      (
        printf '%s\n' "󰤨  Refreshing Wi-Fi networks..."
      ) | $wofi --dmenu --prompt 'Wi-Fi' >/dev/null 2>&1 &
      loading_pid=$!

      $nmcli --wait 15 dev wifi rescan >/dev/null 2>&1 || true

      kill "$loading_pid" >/dev/null 2>&1 || true
      wait "$loading_pid" 2>/dev/null || true
      continue
      ;;
    T)
      ghostty -e nmtui >/dev/null 2>&1 &
      ;;
    N*)
      ssid="${ssid_by_key[$key]:-}"
      [[ -z "$ssid" ]] && continue

      # NetworkManager reuses a matching saved profile, including its credentials.
      if $nmcli dev wifi connect "$ssid" >/dev/null 2>&1; then
        exit 0
      fi

      if [[ "${secure_by_key[$key]:-0}" == "1" ]]; then
        connected=0
        while true; do
          password="$($wofi --dmenu --password --prompt "Password for $ssid" <<< "")" || break
          [[ -z "$password" ]] && break

          if $nmcli dev wifi connect "$ssid" password "$password" >/dev/null 2>&1; then
            connected=1
            break
          fi

          retry_choice="$(printf '%s\n' "R|󰜉  Retry password" "C|󰅖  Cancel" | $wofi --dmenu --prompt "Failed: $ssid")" || break
          retry_key="${retry_choice%%|*}"
          if [[ "$retry_key" != "R" ]]; then
            break
          fi
        done

        if [[ "$connected" == "1" ]]; then
          exit 0
        fi
        continue
      fi

      printf '%s\n' "R|󰑐  Retry connect" "M|󰍺  Back to list" | $wofi --dmenu --prompt "Could not connect to $ssid" >/dev/null || true
      continue
      ;;
    X)
      continue
      ;;
    *)
      exit 0
      ;;
  esac

  exit 0
done
