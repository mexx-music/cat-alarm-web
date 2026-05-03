#!/usr/bin/env bash
set -euo pipefail

# Save a complete project backup labeled "letzte-funk-version-<DATE>" into ./backups
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DATE="$(date +%F)"
LABEL="letzte-funk-version-$DATE"
BACKUP_DIR="$ROOT/backups"
mkdir -p "$BACKUP_DIR"

echo "[backup] Creating backup label: $LABEL"

# Create a git bundle if this is a git repo (fast, small)
if [ -d .git ]; then
  echo "[backup] Creating git bundle..."
  git bundle create "$BACKUP_DIR/$LABEL.bundle" --all || echo "[backup] git bundle failed or nothing to bundle"
fi

# Create a compressed tarball of the project excluding large/derived folders
echo "[backup] Creating tar.gz (this may take a while)..."
tar --exclude='./backups' --exclude='./build' --exclude='./.gradle' --exclude='./.idea' --exclude='./.dart_tool' -czf "$BACKUP_DIR/$LABEL.tar.gz" .

# If an AAB exists from a previous build, copy it into the backup
AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
if [ -f "$AAB_PATH" ]; then
  echo "[backup] Copying existing AAB into backups"
  cp "$AAB_PATH" "$BACKUP_DIR/${LABEL}-app-release.aab"
fi

# Record the latest label for easy restore
echo "$LABEL" > "$BACKUP_DIR/latest_funk_version.txt"

# Print result
echo "[backup] Created backup files:"
ls -lh "$BACKUP_DIR"/*"$LABEL"* || true

echo "[backup] Done. To restore: scripts/restore_funk_version.sh [label] (or no arg to use latest)"

