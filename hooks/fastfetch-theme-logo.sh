#!/bin/bash
# Sanguine's theme-set companion. It snapshots the complete bar layout, every
# plugin state Sanguine mutates, and inactive-window opacity before activation;
# leaving the theme restores that exact baseline.
set -euo pipefail

THEME_NAME=${1:-}
FASTFETCH_CONFIG_DIR="$HOME/.config/fastfetch"
FASTFETCH_CONFIG="$FASTFETCH_CONFIG_DIR/config.jsonc"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"

WORKSPACE_PLUGIN_ID="krampro.sanguine-workspaces"
STOCK_WORKSPACES_ID="omarchy.workspaces"
CLOCK_PLUGIN_ID="shae.clock"
STOCK_CLOCK_ID="omarchy.clock"
POWER_PLUGIN_ID="shae.power"
STOCK_POWER_ID="omarchy.power"
ORNAMENT_PLUGIN_ID="krampro.sanguine-ornament"

WORKSPACE_ANCHOR_FRACTION=0.20
ORNAMENT_ANCHOR_FRACTION=0.70
ORNAMENT_LENGTH_FRACTION=0.10

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

plugin_catalog() {
  omarchy plugin list --json
}

plugin_exists() {
  plugin_catalog | jq -e --arg id "$1" 'any(.[]; .id == $id)' >/dev/null
}

set_plugin_enabled() {
  plugin_exists "$1" || return 0
  omarchy-shell shell setPluginEnabled "$1" "$2" >/dev/null
}

set_inactive_opacity() {
  hyprctl eval "hl.config({ decoration = { inactive_opacity = $1 } })" >/dev/null
}

inactive_opacity() {
  hyprctl getoption decoration:inactive_opacity | awk '/^float:/ { print $2; exit }'
}

capture_bar_state() {
  local catalog opacity temporary
  catalog=$(plugin_catalog)
  opacity=$(inactive_opacity)
  temporary=$(mktemp "${STATE_FILE}.tmp.XXXXXX")

  jq \
    --argjson catalog "$catalog" \
    --arg workspace "$WORKSPACE_PLUGIN_ID" \
    --arg stockWorkspace "$STOCK_WORKSPACES_ID" \
    --arg clock "$CLOCK_PLUGIN_ID" \
    --arg stockClock "$STOCK_CLOCK_ID" \
    --arg power "$POWER_PLUGIN_ID" \
    --arg stockPower "$STOCK_POWER_ID" \
    --arg ornament "$ORNAMENT_PLUGIN_ID" \
    --argjson inactiveOpacity "$opacity" '
      def enabled($id): first($catalog[] | select(.id == $id) | .enabled) // false;
      {
        version: 4,
        layout: (.bar.layout // { left: [], center: [], right: [] }),
        centerAnchor: (.bar.centerAnchor // "omarchy.clock"),
        pluginStates: {
          ($workspace): enabled($workspace),
          ($stockWorkspace): enabled($stockWorkspace),
          ($clock): enabled($clock),
          ($stockClock): enabled($stockClock),
          ($power): enabled($power),
          ($stockPower): enabled($stockPower),
          ($ornament): enabled($ornament)
        },
        inactiveOpacity: $inactiveOpacity
      }
    ' "$SHELL_CONFIG" >"$temporary"
  mv "$temporary" "$STATE_FILE"
}

# Older state tracked fewer plugins and did not preserve the bar's center
# anchor. Infer missing values from the untouched baseline layout/config.
migrate_state() {
  [[ -f $STATE_FILE ]] || return 0
  [[ $(jq -r '.version // 1' "$STATE_FILE") -ge 4 ]] && return 0

  local temporary center_anchor
  center_anchor=$(jq -r '.bar.centerAnchor // "omarchy.clock"' "$SHELL_CONFIG")
  temporary=$(mktemp "${STATE_FILE}.tmp.XXXXXX")
  jq \
    --arg workspace "$WORKSPACE_PLUGIN_ID" \
    --arg stockWorkspace "$STOCK_WORKSPACES_ID" \
    --arg clock "$CLOCK_PLUGIN_ID" \
    --arg stockClock "$STOCK_CLOCK_ID" \
    --arg power "$POWER_PLUGIN_ID" \
    --arg stockPower "$STOCK_POWER_ID" \
    --arg ornament "$ORNAMENT_PLUGIN_ID" \
    --arg centerAnchor "$center_anchor" '
      def present($id): any([.layout.left[], .layout.center[], .layout.right[]][]?; .id == $id);
      .version = 4 |
      .centerAnchor = (.centerAnchor // $centerAnchor) |
      .pluginStates = {
        ($workspace): (.customEnabled // present($workspace)),
        ($stockWorkspace): (.stockEnabled // present($stockWorkspace)),
        ($clock): present($clock),
        ($stockClock): present($stockClock),
        ($power): present($power),
        ($stockPower): present($stockPower),
        ($ornament): present($ornament)
      } |
      del(.customEnabled, .stockEnabled)
    ' "$STATE_FILE" >"$temporary"
  mv "$temporary" "$STATE_FILE"
}

activate_bar_plugins() {
  [[ -f $SHELL_CONFIG ]] || return 0
  [[ -f $STATE_FILE ]] || capture_bar_state
  migrate_state

  local has_workspace=false has_clock=false has_power=false has_ornament=false temporary
  plugin_exists "$WORKSPACE_PLUGIN_ID" && has_workspace=true
  plugin_exists "$CLOCK_PLUGIN_ID" && has_clock=true
  plugin_exists "$POWER_PLUGIN_ID" && has_power=true
  plugin_exists "$ORNAMENT_PLUGIN_ID" && has_ornament=true

  temporary=$(mktemp "${SHELL_CONFIG}.tmp.XXXXXX")
  jq \
    --slurpfile state "$STATE_FILE" \
    --arg workspace "$WORKSPACE_PLUGIN_ID" \
    --arg stockWorkspace "$STOCK_WORKSPACES_ID" \
    --arg clock "$CLOCK_PLUGIN_ID" \
    --arg stockClock "$STOCK_CLOCK_ID" \
    --arg power "$POWER_PLUGIN_ID" \
    --arg stockPower "$STOCK_POWER_ID" \
    --arg ornament "$ORNAMENT_PLUGIN_ID" \
    --argjson hasWorkspace "$has_workspace" \
    --argjson hasClock "$has_clock" \
    --argjson hasPower "$has_power" \
    --argjson hasOrnament "$has_ornament" \
    --argjson workspaceAnchor "$WORKSPACE_ANCHOR_FRACTION" \
    --argjson ornamentAnchor "$ORNAMENT_ANCHOR_FRACTION" \
    --argjson ornamentLength "$ORNAMENT_LENGTH_FRACTION" '
      ($state[0].layout // { left: [], center: [], right: [] }) as $original |

      (if $hasWorkspace then
        ([ ["left", "center", "right"][] as $section
           | ($original[$section] // []) | to_entries[]
           | select(.value.id == $workspace or .value.id == $stockWorkspace)
           | { section: $section, index: .key, entry: .value }
        ]) as $slots |
        ([ ($original.left // []) | to_entries[] | select(.value.id == "omarchy.menu") | .key + 1 ] | .[0] // 0) as $menuIndex |
        ($slots[0] // { section: "left", index: $menuIndex }) as $target |
        ($original |
          .left = [(.left // [])[] | select(.id != $workspace and .id != $stockWorkspace)] |
          .center = [(.center // [])[] | select(.id != $workspace and .id != $stockWorkspace)] |
          .right = [(.right // [])[] | select(.id != $workspace and .id != $stockWorkspace)]
        ) as $clean |
        ($target.index | if . > ($clean[$target.section] | length) then ($clean[$target.section] | length) else . end) as $index |
        ($clean | .[$target.section] = (
          .[$target.section][0:$index] +
          [{ id: $workspace, horizontalAnchorFraction: $workspaceAnchor }] +
          .[$target.section][$index:]
        ))
      else $original end) as $withWorkspace |

      (if $hasClock then
        $withWorkspace |
        .left |= map(if .id == $stockClock or .id == $clock then .id = $clock else . end) |
        .center |= map(if .id == $stockClock or .id == $clock then .id = $clock else . end) |
        .right |= map(if .id == $stockClock or .id == $clock then .id = $clock else . end)
      else $withWorkspace end) as $withClock |

      (if $hasPower then
        $withClock |
        .left |= map(if .id == $stockPower or .id == $power then .id = $power else . end) |
        .center |= map(if .id == $stockPower or .id == $power then .id = $power else . end) |
        .right |= map(if .id == $stockPower or .id == $power then .id = $power else . end)
      else $withClock end) as $withPower |

      (if $hasOrnament then
        ($withPower |
          .left = [(.left // [])[] | select(.id != $ornament)] |
          .center = [(.center // [])[] | select(.id != $ornament)] |
          .right = [(.right // [])[] | select(.id != $ornament)]
        ) as $clean |
        ([ $clean.center | to_entries[] | select(.value.id == "omarchy.system-update") | .key + 1 ] |
          .[0] // ($clean.center | length)) as $index |
        ($clean | .center = (
          .center[0:$index] +
          [{ id: $ornament, horizontalAnchorFraction: $ornamentAnchor, lengthFraction: $ornamentLength }] +
          .center[$index:]
        ))
      else $withPower end) as $activated |

      .bar.layout = $activated |
      .bar.centerAnchor = (if $hasClock then $clock else ($state[0].centerAnchor // "omarchy.clock") end)
    ' "$SHELL_CONFIG" >"$temporary"
  mv "$temporary" "$SHELL_CONFIG"
  omarchy-shell shell reloadConfig >/dev/null

  if [[ $has_workspace == true ]]; then
    set_plugin_enabled "$WORKSPACE_PLUGIN_ID" true
    set_plugin_enabled "$STOCK_WORKSPACES_ID" false
  fi
  if [[ $has_clock == true ]]; then
    set_plugin_enabled "$CLOCK_PLUGIN_ID" true
    set_plugin_enabled "$STOCK_CLOCK_ID" false
  fi
  if [[ $has_power == true ]]; then
    set_plugin_enabled "$POWER_PLUGIN_ID" true
    set_plugin_enabled "$STOCK_POWER_ID" false
  fi
  [[ $has_ornament == true ]] && set_plugin_enabled "$ORNAMENT_PLUGIN_ID" true
}

restore_bar_state() {
  [[ -f $STATE_FILE && -f $SHELL_CONFIG ]] || return 0
  migrate_state

  local temporary
  temporary=$(mktemp "${SHELL_CONFIG}.tmp.XXXXXX")
  jq --slurpfile state "$STATE_FILE" '
    .bar.layout = ($state[0].layout // { left: [], center: [], right: [] }) |
    .bar.centerAnchor = ($state[0].centerAnchor // "omarchy.clock")
  ' "$SHELL_CONFIG" >"$temporary"
  mv "$temporary" "$SHELL_CONFIG"
  omarchy-shell shell reloadConfig >/dev/null

  while IFS=$'\t' read -r id enabled; do
    set_plugin_enabled "$id" "$enabled"
  done < <(jq -r '.pluginStates | to_entries[] | [.key, .value] | @tsv' "$STATE_FILE")

  set_inactive_opacity "$(jq -r '.inactiveOpacity // 1.0' "$STATE_FILE")"
  rm -f "$STATE_FILE"
}

reset_fastfetch
if [[ ${THEME_NAME,,} == sanguine ]]; then
  apply_sanguine_fastfetch
  activate_bar_plugins
  set_inactive_opacity 0.98
else
  restore_bar_state
fi