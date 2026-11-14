#!/usr/bin/env bash
# Build locally, including the generated Clay assets that are not stored in Git.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

godot_bin="${GODOT_BIN:-}"
if [[ -z "$godot_bin" ]]; then
  if command -v godot >/dev/null 2>&1; then
    godot_bin="$(command -v godot)"
  elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
    godot_bin=/Applications/Godot.app/Contents/MacOS/Godot
  else
    echo 'Godot not found. Set GODOT_BIN to your Godot executable.' >&2
    exit 1
  fi
fi

for asset in game/assets/clay.glb game/assets/clay_rig.json; do
  if [[ ! -s "$asset" ]]; then
    echo "Missing $asset. Build Clay first; see game/README.md." >&2
    exit 1
  fi
done

python_bin="${PYTHON_BIN:-python3}"
# Ensure the desktop import exists before deriving the isolated web settings.
"$godot_bin" --headless --path game --editor --import --quit
"$python_bin" tools/prepare_web_export.py prepare
"$godot_bin" --headless --path cache/web-build/game --editor --import --quit
"$godot_bin" --headless --path cache/web-build/game --export-release Web "$repo_dir/game/exports/web/index.html"
"$python_bin" tools/prepare_web_export.py finalize
echo 'Web build ready: game/exports/web'
echo 'Preview: python3 tools/serve_web.py'
echo 'Deploy: cd game/exports/web && npx vercel'
