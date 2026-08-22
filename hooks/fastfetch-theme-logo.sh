#!/bin/bash
# Reset fastfetch to the Omarchy default config, then swap in the active
# theme's logo. Sanguine gets its skull; other themes keep the default.

CONFIG_DIR="$HOME/.config/fastfetch"
CONFIG="$CONFIG_DIR/config.jsonc"

mkdir -p "$CONFIG_DIR"
cp /etc/fastfetch/config.jsonc "$CONFIG"

shopt -s nocasematch
if [[ "$1" == "sanguine" ]]; then
  sed -i "s|\"source\": \"[^\"]*\"|\"source\": \"$HOME/.config/omarchy/themes/sanguine/logo-ascii.txt\"|" "$CONFIG"
  # Tighten padding to reclaim columns for the wider logo
  sed -i "s|\"right\": [0-9]*|\"right\": 1|" "$CONFIG"
  sed -i "s|\"left\": [0-9]*|\"left\": 1|" "$CONFIG"
fi
