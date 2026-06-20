#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${VPN_MAC_CONFIG:-$HOME/.config/vpn-mac/config.env}"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi

VPN_USER="${VPN_USER:-}"
KEYCHAIN_SERVICE="${KEYCHAIN_SERVICE:-vpn-mac}"

echo "=== VPN Keychain 設定 ==="
echo

if [[ -z "$VPN_USER" ]]; then
  read -r -p "VPN 帳號: " VPN_USER
fi

read -r -s -p "VPN 密碼: " VPN_PASSWORD
echo

if security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$VPN_USER" >/dev/null 2>&1; then
  echo "更新既有 Keychain 項目 ..."
  security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$VPN_USER" >/dev/null
fi

security add-generic-password \
  -s "$KEYCHAIN_SERVICE" \
  -a "$VPN_USER" \
  -w "$VPN_PASSWORD" \
  -T "/usr/bin/security" \
  -T "/bin/bash" \
  -T "/bin/zsh"

echo
echo "已儲存到 Keychain"
echo "  Service : $KEYCHAIN_SERVICE"
echo "  Account : $VPN_USER"
echo
echo "之後連線時會自動讀取，不需再手動輸入密碼。"
