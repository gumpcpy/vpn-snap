#!/usr/bin/env bash

make_icns() {
  local png="$1"
  local output="$2"
  local iconset="${output%.icns}.iconset"

  if [[ ! -f "$png" ]]; then
    echo "找不到圖示: $png" >&2
    return 1
  fi

  rm -rf "$iconset"
  mkdir -p "$iconset"

  sips -z 16 16   "$png" --out "$iconset/icon_16x16.png"       >/dev/null
  sips -z 32 32   "$png" --out "$iconset/icon_16x16@2x.png"    >/dev/null
  sips -z 32 32   "$png" --out "$iconset/icon_32x32.png"       >/dev/null
  sips -z 64 64   "$png" --out "$iconset/icon_32x32@2x.png"    >/dev/null
  sips -z 128 128 "$png" --out "$iconset/icon_128x128.png"     >/dev/null
  sips -z 256 256 "$png" --out "$iconset/icon_128x128@2x.png"  >/dev/null
  sips -z 256 256 "$png" --out "$iconset/icon_256x256.png"     >/dev/null
  sips -z 512 512 "$png" --out "$iconset/icon_256x256@2x.png"  >/dev/null
  sips -z 512 512 "$png" --out "$iconset/icon_512x512.png"     >/dev/null
  cp "$png" "$iconset/icon_512x512@2x.png"

  iconutil -c icns "$iconset" -o "$output"
  rm -rf "$iconset"
}
