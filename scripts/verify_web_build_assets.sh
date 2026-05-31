#!/usr/bin/env bash
# Verifies Flutter Web build output contains runtime-critical map assets.
# Flutter Web places pubspec assets under build/web/assets/assets/…
set -euo pipefail

BUILD_DIR="${1:-build/web}"
ASSET_ROOT="${BUILD_DIR}/assets/assets"

required_files=(
  "map_3d/models/map_island.glb"
  "map_3d/models/spark.glb"
  "map_3d/index.html"
  "map_3d/js/main.js"
  "data/levels.json"
)

missing=()
for rel in "${required_files[@]}"; do
  path="${ASSET_ROOT}/${rel}"
  if [[ ! -f "$path" ]]; then
    missing+=("$path")
  fi
done

if ((${#missing[@]} > 0)); then
  echo "ERROR: Web build is missing required assets (deploy would 404):" >&2
  printf '  %s\n' "${missing[@]}" >&2
  echo "Asset tree under ${ASSET_ROOT}:" >&2
  find "${ASSET_ROOT}" -type f 2>/dev/null | head -50 >&2 || true
  exit 1
fi

echo "All required web build assets present under ${ASSET_ROOT}"
