#!/usr/bin/env bash

CONFIG_FILE="${VPN_MAC_CONFIG:-$HOME/.config/vpn-mac/config.env}"
PROFILES_DIR="${VPN_MAC_PROFILES_DIR:-$HOME/.config/vpn-mac/profiles}"

profiles_dir() {
  printf '%s' "$PROFILES_DIR"
}

profile_path() {
  local name="${1%.env}"
  printf '%s/%s.env' "$(profiles_dir)" "$name"
}

list_profile_names() {
  local f name
  shopt -s nullglob
  for f in "$(profiles_dir)"/*.env; do
    name="$(basename "$f" .env)"
    printf '%s\n' "$name"
  done
  shopt -u nullglob
}

get_active_profile() {
  local active="${ACTIVE_PROFILE:-}"
  if [[ -n "$active" && -f "$(profile_path "$active")" ]]; then
    printf '%s' "$active"
    return 0
  fi
  printf '%s' ""
}

load_profile_file() {
  local profile="$1"
  local file
  file="$(profile_path "$profile")"

  if [[ ! -f "$file" ]]; then
    echo "找不到線路設定: $file" >&2
    echo "可用指令: vpn-list" >&2
    return 1
  fi

  # shellcheck source=/dev/null
  source "$file"
  CURRENT_PROFILE="$profile"
}

load_config() {
  local profile_override="${1:-}"

  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "找不到設定檔: $CONFIG_FILE" >&2
    echo "請先執行: ./setup.sh" >&2
    return 1
  fi

  # shellcheck source=/dev/null
  source "$CONFIG_FILE"

  : "${VPN_BIN:=/opt/cisco/secureclient/bin/vpn}"
  : "${KEYCHAIN_SERVICE:=vpn-mac}"
  : "${AUTO_CONFIRM:=y}"
  : "${TRUST_SERVER_CERT:=y}"
  : "${IMPORT_SERVER_CERT:=y}"

  local profile=""
  if [[ -n "$profile_override" ]]; then
    profile="$profile_override"
  else
    profile="$(get_active_profile)"
  fi

  if [[ -n "$profile" ]]; then
    load_profile_file "$profile"
  fi

  if [[ -z "${VPN_HOST:-}" || -z "${VPN_USER:-}" ]]; then
    echo "請設定 VPN_HOST 與 VPN_USER" >&2
    echo "  - 在 profiles/<名稱>.env 建立線路，或" >&2
    echo "  - 在 $CONFIG_FILE 直接設定（舊版方式）" >&2
    return 1
  fi

  if [[ ! -x "$VPN_BIN" ]]; then
    echo "找不到 Cisco VPN CLI: $VPN_BIN" >&2
    return 1
  fi
}

set_active_profile() {
  local profile="$1"
  local tmp

  if [[ ! -f "$(profile_path "$profile")" ]]; then
    echo "找不到線路: $profile" >&2
    return 1
  fi

  if grep -q '^ACTIVE_PROFILE=' "$CONFIG_FILE"; then
    tmp="$(mktemp)"
    sed "s/^ACTIVE_PROFILE=.*/ACTIVE_PROFILE=\"$profile\"/" "$CONFIG_FILE" > "$tmp"
    mv "$tmp" "$CONFIG_FILE"
  else
    printf '\nACTIVE_PROFILE="%s"\n' "$profile" >> "$CONFIG_FILE"
  fi
}

profile_label() {
  printf '%s' "${PROFILE_LABEL:-${CURRENT_PROFILE:-$ACTIVE_PROFILE}}"
}

get_password() {
  local password
  if ! password="$(security find-generic-password -w -s "$KEYCHAIN_SERVICE" -a "$VPN_USER" 2>/dev/null)"; then
    echo "無法從 Keychain 讀取密碼（service=$KEYCHAIN_SERVICE, account=$VPN_USER）" >&2
    echo "請先執行: ./setup-keychain.sh" >&2
    return 1
  fi
  printf '%s' "$password"
}

notify() {
  local title="$1"
  local message="$2"
  osascript -e "display notification \"$message\" with title \"$title\"" >/dev/null 2>&1 || true
}

vpn_state() {
  printf 'state\nexit\n' | "$VPN_BIN" -s 2>/dev/null \
    | grep 'state:' \
    | tail -1 \
    | sed 's/^[^:]*: *//'
}

is_connected() {
  local state
  state="$(vpn_state)"
  [[ "$state" == "Connected" ]] || [[ "$state" == *"Connected to"* ]]
}

build_vpn_input() {
  local password="$1"

  if [[ -n "${TRUST_SERVER_CERT:-}" ]]; then
    printf '%s\n' "$TRUST_SERVER_CERT"
  fi
  if [[ -n "${IMPORT_SERVER_CERT:-}" ]]; then
    printf '%s\n' "$IMPORT_SERVER_CERT"
  fi

  printf '%s\n%s' "$VPN_USER" "$password"
  if [[ -n "${MFA_OPTION:-}" ]]; then
    printf '\n%s' "$MFA_OPTION"
  fi
  if [[ -n "${AUTO_CONFIRM:-}" ]]; then
    printf '\n%s' "$AUTO_CONFIRM"
  fi
}
