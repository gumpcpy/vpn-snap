#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/vpn-mac"
CONFIG_FILE="$CONFIG_DIR/config.env"
PROFILES_DIR="$CONFIG_DIR/profiles"
LOCAL_BIN="$HOME/.local/bin"

# shellcheck source=lib/icons.sh
source "$SCRIPT_DIR/lib/icons.sh"

echo "=== VpnSnap 安裝 ==="
echo

mkdir -p "$CONFIG_DIR" "$PROFILES_DIR" "$LOCAL_BIN"

if [[ ! -f "$CONFIG_FILE" ]]; then
  cp "$SCRIPT_DIR/config.env.example" "$CONFIG_FILE"
  echo "已建立設定檔: $CONFIG_FILE"
else
  echo "設定檔已存在: $CONFIG_FILE"
fi

# 從舊版單一設定遷移到 profiles/
if [[ -z "$(ls -A "$PROFILES_DIR" 2>/dev/null || true)" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE" 2>/dev/null || true
  if [[ -n "${VPN_HOST:-}" && -n "${VPN_USER:-}" ]]; then
    cat > "$PROFILES_DIR/primary.env" <<EOF
PROFILE_LABEL="主線路"

VPN_HOST="$VPN_HOST"
VPN_USER="$VPN_USER"
EOF
    if ! grep -q '^ACTIVE_PROFILE=' "$CONFIG_FILE"; then
      printf '\nACTIVE_PROFILE="primary"\n' >> "$CONFIG_FILE"
    fi
    echo "已將現有設定遷移到: $PROFILES_DIR/primary.env"
  else
    cp "$SCRIPT_DIR/profiles/primary.env.example" "$PROFILES_DIR/primary.env"
    cp "$SCRIPT_DIR/profiles/backup.env.example" "$PROFILES_DIR/backup.env"
    echo "已建立範例線路: primary.env、backup.env（請編輯 backup.env）"
  fi
fi

for cmd in vpn-connect vpn-disconnect vpn-status vpn-list vpn-switch; do
  ln -sf "$SCRIPT_DIR/bin/$cmd" "$LOCAL_BIN/$cmd"
  chmod +x "$SCRIPT_DIR/bin/$cmd"
  echo "已連結: $LOCAL_BIN/$cmd"
done

chmod +x "$SCRIPT_DIR/lib/common.sh"
chmod +x "$SCRIPT_DIR/setup-keychain.sh"

create_app() {
  local app_name="$1"
  local script_name="$2"
  local bundle_id="$3"
  local icon_png="$4"
  local app_dir="$HOME/Applications/${app_name}.app"
  local macos_dir="$app_dir/Contents/MacOS"
  local resources_dir="$app_dir/Contents/Resources"

  mkdir -p "$macos_dir" "$resources_dir"

  if [[ -f "$icon_png" ]]; then
    make_icns "$icon_png" "$resources_dir/AppIcon.icns"
  fi

  cat > "$app_dir/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>launcher</string>
  <key>CFBundleIdentifier</key>
  <string>${bundle_id}</string>
  <key>CFBundleName</key>
  <string>${app_name}</string>
  <key>CFBundleDisplayName</key>
  <string>${app_name}</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
</dict>
</plist>
EOF

  cat > "$macos_dir/launcher" <<EOF
#!/bin/bash
export PATH="/usr/local/bin:/opt/homebrew/bin:\$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
exec "$SCRIPT_DIR/bin/${script_name}" --quiet
EOF

  chmod +x "$macos_dir/launcher"
  echo "已建立 App: $app_dir"
}

create_app "VpnSnap" "vpn-connect" "com.vpnsnap.connect" "$SCRIPT_DIR/assets/icons/connect.png"
create_app "VpnSnap Disconnect" "vpn-disconnect" "com.vpnsnap.disconnect" "$SCRIPT_DIR/assets/icons/disconnect.png"

# 移除舊版無圖示 App
rm -rf "$HOME/Applications/VPN Connect.app" "$HOME/Applications/VPN Disconnect.app"

echo
echo "安裝完成。"
echo
echo "建議放置方式（比桌面乾淨）："
echo "  1. 終端機: vpn-connect / vpn-switch / vpn-list"
echo "  2. 啟動台: ~/Applications/VpnSnap.app"
echo "  3. Spotlight: 搜尋「VpnSnap」"
echo
echo "下一步："
echo "  1. 編輯 $PROFILES_DIR/*.env 設定各條線路"
echo "  2. 執行 ./setup-keychain.sh"
echo "  3. 測試: vpn-list && vpn-connect"

if ! echo ":$PATH:" | grep -q ":$LOCAL_BIN:"; then
  echo
  echo "提醒: 你的 PATH 可能還沒包含 $LOCAL_BIN"
  echo "可在 ~/.zshrc 加入:"
  echo '  export PATH="$HOME/.local/bin:$PATH"'
fi
