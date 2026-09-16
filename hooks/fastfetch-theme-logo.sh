#!/bin/bash
# Sanguine's theme-set companion: reconstruct Fastfetch and reconcile only the
# workspace slot that the Sanguine plugin owns. It snapshots that slot before
# activation and restores it exactly when the theme is left.
set -euo pipefail

THEME_NAME=${1:-}
FASTFETCH_CONFIG_DIR="$HOME/.config/fastfetch"
FASTFETCH_CONFIG="$FASTFETCH_CONFIG_DIR/config.jsonc"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
PLUGIN_ID="krampro.sanguine-workspaces"
STOCK_WORKSPACES_ID="omarchy.workspaces"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/sanguine-workspaces"
STATE_FILE="$STATE_DIR/theme-set.json"

mkdir -p "$STATE_DIR"
exec 9>"$STATE_DIR/theme-set.lock"
flock 9

reset_fastfetch() {
  mkdir -p "$FASTFETCH_CONFIG_DIR"
  cp /etc/fastfetch/config.jsonc "$FASTFETCH_CONFIG"
}

apply_sanguine_fastfetch() {
  sed -i "s|\"source\": \"[^\"]*\"|\"source\": \"$HOME/.config/omarchy/themes/sanguine/logo-ascii.txt\"|" "$FASTFETCH_CONFIG"
  sed -i "s|\"right\": [0-9]*|\"right\": 1|" "$FASTFETCH_CONFIG"
  sed -i "s|\"left\": [0-9]*|\"left\": 1|" "$FASTFETCH_CONFIG"
}

plugin_exists() {
  omarchy plugin list --json | jq -e --arg id "$1" 'any(.[]; .id == $id)' >/dev/null
}

plugin_enabled() {
  omarchy plugin list --json | jq -r --arg id "$1" 'first(.[] | select(.id == $id) | .enabled) // false'
}

set_plugin_enabled() {
  omarchy-shell shell setPluginEnabled "$1" "$2" >/dev/null
}

set_inactive_opacity() {
  hyprctl eval "hl.config({ decoration = { inactive_opacity = $1 } })" >/dev/null
}

inactive_opacity() {
  hyprctl getoption decoration:inactive_opacity | awk '/^float:/ { print $2; exit }'
}

capture_workspace_state() {
  local custom_enabled stock_enabled opacity temporary
  custom_enabled=$(plugin_enabled "$PLUGIN_ID")
  stock_enabled=$(plugin_enabled "$STOCK_WORKSPACES_ID")
  opacity=$(inactive_opacity)
  temporary=$(mktemp "${STATE_FILE}.tmp.XXXXXX")
  jq --argjson customEnabled "$custom_enabled" --argjson stockEnabled "$stock_enabled" --argjson inactiveOpacity "$opacity" '
    {
      version: 2,
      layout: (.bar.layout // { left: [], center: [], right: [] }),
      customEnabled: $customEnabled,
      stockEnabled: $stockEnabled,
      inactiveOpacity: $inactiveOpacity
    }
  ' "$SHELL_CONFIG" >"$temporary"
  mv "$temporary" "$STATE_FILE"
}

activate_workspace_plugin() {
  plugin_exists "$PLUGIN_ID" || return 0
  [[ -f $SHELL_CONFIG ]] || return 0

  if [[ ! -f $STATE_FILE ]]; then
    capture_workspace_state
  fi

  local temporary
  temporary=$(mktemp "${SHELL_CONFIG}.tmp.XXXXXX")
  jq --slurpfile state "$STATE_FILE" --arg plugin "$PLUGIN_ID" --arg stock "$STOCK_WORKSPACES_ID" '
    ($state[0].layout // { left: ($state[0].left // []), center: [], right: [] }) as $original |
    ([ ["left", "center", "right"][] as $section
       | ($original[$section] // []) | to_entries[]
       | select(.value.id == $plugin or .value.id == $stock)
       | { section: $section, index: .key, entry: .value }
    ]) as $slots |
    ($slots | map(select(.entry.id == $plugin)) | .[0].entry // { id: $plugin }) as $pluginEntry |
    ([ ($original.left // []) | to_entries[] | select(.value.id == "omarchy.menu") | .key + 1 ] | .[0] // 0) as $menuIndex |
    ($slots[0] // { section: "left", index: $menuIndex }) as $target |
    .bar.layout |= (
      .left = [(.left // [])[] | select(.id != $plugin and .id != $stock)] |
      .center = [(.center // [])[] | select(.id != $plugin and .id != $stock)] |
      .right = [(.right // [])[] | select(.id != $plugin and .id != $stock)]
    ) |
    (.bar.layout[$target.section] // []) as $clean |
    ($target.index | if . > ($clean | length) then ($clean | length) else . end) as $index |
    .bar.layout[$target.section] = ($clean[0:$index] + [$pluginEntry] + $clean[$index:])
  ' "$SHELL_CONFIG" >"$temporary"
  mv "$temporary" "$SHELL_CONFIG"
  omarchy-shell shell reloadConfig >/dev/null
  set_plugin_enabled "$PLUGIN_ID" true
  set_plugin_enabled "$STOCK_WORKSPACES_ID" false
}

restore_workspace_state() {
  [[ -f $STATE_FILE && -f $SHELL_CONFIG ]] || return 0

  local temporary
  temporary=$(mktemp "${SHELL_CONFIG}.tmp.XXXXXX")
  jq --slurpfile state "$STATE_FILE" '
    .bar.layout = ($state[0].layout // { left: ($state[0].left // .bar.layout.left), center: .bar.layout.center, right: .bar.layout.right })
  ' "$SHELL_CONFIG" >"$temporary"
  mv "$temporary" "$SHELL_CONFIG"
  omarchy-shell shell reloadConfig >/dev/null
  set_plugin_enabled "$PLUGIN_ID" "$(jq -r '.customEnabled' "$STATE_FILE")"
  set_plugin_enabled "$STOCK_WORKSPACES_ID" "$(jq -r '.stockEnabled' "$STATE_FILE")"
  set_inactive_opacity "$(jq -r '.inactiveOpacity // 1.0' "$STATE_FILE")"
  rm -f "$STATE_FILE"
}

reset_fastfetch
if [[ $THEME_NAME == sanguine ]]; then
  apply_sanguine_fastfetch
  activate_workspace_plugin
  set_inactive_opacity 0.98
else
  restore_workspace_state
fi
