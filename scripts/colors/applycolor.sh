#!/usr/bin/env bash

export PATH="$HOME/.local/bin:$PATH"

QUICKSHELL_CONFIG_NAME="end4-pC"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

term_alpha=100 #Set this to < 100 make all your terminals transparent
# sleep 0 # idk i wanted some delay or colors dont get applied properly
if [ ! -d "$STATE_DIR"/user/generated ]; then
  mkdir -p "$STATE_DIR"/user/generated
fi
cd "$CONFIG_DIR" || exit

colornames=''
colorstrings=''
colorlist=()
colorvalues=()

colornames=$(cat $STATE_DIR/user/generated/material_colors.scss | cut -d: -f1)
colorstrings=$(cat $STATE_DIR/user/generated/material_colors.scss | cut -d: -f2 | cut -d ' ' -f2 | cut -d ";" -f1)
IFS=$'\n'
colorlist=($colornames)     # Array of color names
colorvalues=($colorstrings) # Array of color values

apply_kitty() {  
  # Check if terminal escape sequence template exists
  if [ ! -f "$SCRIPT_DIR/terminal/kitty-theme.conf" ]; then
    echo "Template file not found for Kitty theme. Skipping that."
    return
  fi
  if [ ! -f "$STATE_DIR/user/generated/material_colors.scss" ]; then
    return
  fi

  mkdir -p "$STATE_DIR"/user/generated/terminal
  local target_file="$STATE_DIR/user/generated/terminal/kitty-theme.conf"
  local tmp_file="$target_file.tmp.$$"

  python3 -c '
import sys, os, re

scss_path, tpl_path, tmp_path = sys.argv[1:4]
colors = {}
with open(scss_path) as f:
    for line in f:
        line = line.strip()
        if ":" in line:
            k, v = line.split(":", 1)
            colors[k.strip()] = v.split(";")[0].strip().lstrip("#")

with open(tpl_path) as f:
    content = f.read()

for k, v in colors.items():
    content = content.replace(f"{k} #", v)

# Strip invalid C++ style comments if present
content = re.sub(r"\s*//.*", "", content)

# Abort if unreplaced template variables remain
if re.search(r"\$[a-zA-Z0-9_]+\s*#", content):
    sys.exit(1)

with open(tmp_path, "w") as f:
    f.write(content)
' "$STATE_DIR/user/generated/material_colors.scss" "$SCRIPT_DIR/terminal/kitty-theme.conf" "$tmp_file" 2>/dev/null

  if [ -s "$tmp_file" ]; then
    mv -f "$tmp_file" "$target_file"
  else
    rm -f "$tmp_file"
    return 1
  fi

  # Reload colors via socket if available to preserve user font zoom/scaling
  if command -v kitten &>/dev/null; then
    kitten @ --to unix:@kitty set-colors --all --configured "$target_file" 2>/dev/null || pkill -SIGUSR1 -x kitty 2>/dev/null || true
  else
    pkill -SIGUSR1 -x kitty 2>/dev/null || true
  fi
}

apply_anyterm() {
  # Check if terminal escape sequence template exists
  if [ ! -f "$SCRIPT_DIR/terminal/sequences.txt" ]; then
    echo "Template file not found for Terminal. Skipping that."
    return
  fi
  if [ ! -f "$STATE_DIR/user/generated/material_colors.scss" ]; then
    return
  fi

  mkdir -p "$STATE_DIR"/user/generated/terminal
  local target_file="$STATE_DIR/user/generated/terminal/sequences.txt"
  local tmp_file="$target_file.tmp.$$"

  python3 -c '
import sys, os

scss_path, tpl_path, tmp_path, alpha = sys.argv[1:5]
colors = {}
with open(scss_path) as f:
    for line in f:
        line = line.strip()
        if ":" in line:
            k, v = line.split(":", 1)
            colors[k.strip()] = v.split(";")[0].strip().lstrip("#")

with open(tpl_path) as f:
    content = f.read()

for k, v in colors.items():
    content = content.replace(f"{k} #", v)

content = content.replace("$alpha", alpha)

with open(tmp_path, "w") as f:
    f.write(content)
' "$STATE_DIR/user/generated/material_colors.scss" "$SCRIPT_DIR/terminal/sequences.txt" "$tmp_file" "$term_alpha" 2>/dev/null

  if [ -s "$tmp_file" ]; then
    mv -f "$tmp_file" "$target_file"
  else
    rm -f "$tmp_file"
    return 1
  fi

  # Note: Broadcasting raw escape sequences to all /dev/pts/* is disabled
  # because it corrupts libadwaita terminals (Ptyxis/Prompt) contrast and
  # triggered the KDE kwrited notification bug. Kitty uses apply_kitty directly.
}

apply_term() {
  apply_kitty
  apply_anyterm
}

apply_qt() {
  sh "$CONFIG_DIR/scripts/kvantum/materialQT.sh"          # generate kvantum theme
  python "$CONFIG_DIR/scripts/kvantum/changeAdwColors.py" # apply config colors
}

# Check if terminal theming is enabled in config
CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
if [ -f "$CONFIG_FILE" ]; then
  enable_terminal=$(jq -r '.appearance.wallpaperTheming.enableTerminal' "$CONFIG_FILE")
  if [ "$enable_terminal" = "true" ]; then
    apply_term &
  fi
else
  echo "Config file not found at $CONFIG_FILE. Applying terminal theming by default."
  apply_term &
fi

# apply_qt & # Qt theming is already handled by kde-material-colors
