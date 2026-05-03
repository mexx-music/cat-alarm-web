#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BACKUP_DIR="$ROOT/backups"
LATEST_FILE="$BACKUP_DIR/latest_funk_version.txt"

if [ $# -eq 0 ]; then
  if [ -f "$LATEST_FILE" ]; then
    LABEL=$(cat "$LATEST_FILE")
    echo "[restore] No label provided. Using latest: $LABEL"
  else
    echo "[restore] No label provided and no latest record found. Aborting."
    exit 1
  fi
else
  LABEL="$1"
  echo "[restore] Using label: $LABEL"
fi

BUNDLE="$BACKUP_DIR/$LABEL.bundle"
TAR="$BACKUP_DIR/$LABEL.tar.gz"

if [ -f "$BUNDLE" ]; then
  echo "[restore] Restoring from git bundle: $BUNDLE"
  # If repo exists, move aside current to restore clean
  if [ -d .git ]; then
    echo "[restore] Existing .git found, renaming to .git.bak"
    mv .git .git.bak_$(date +%s)
  fi
  mkdir -p restore_tmp
  cd restore_tmp
  git clone --mirror "$BUNDLE" repo.git
  cd repo.git
  git clone . ../restored_repo
  cd ../restored_repo
  mv ../restored_repo/* "$ROOT" || true
  cd "$ROOT"
  rm -rf restore_tmp
  echo "[restore] Git bundle restored. Run 'git status' to verify."
  exit 0
fi

if [ -f "$TAR" ]; then
  echo "[restore] Restoring from tarball: $TAR"
  # Extract to temp folder then replace files (keep backups folder)
  TMPDIR="$ROOT/restore_tmp_$$"
  mkdir -p "$TMPDIR"
  tar -xzf "$TAR" -C "$TMPDIR"
  echo "[restore] Copying files back to project (this will overwrite)"
  shopt -s dotglob
  rsync -a --delete --exclude 'backups' "$TMPDIR/" "$ROOT/"
  rm -rf "$TMPDIR"
  echo "[restore] Restore complete. Run 'flutter pub get' and rebuild."
  exit 0
fi

echo "[restore] No bundle or tar found for label: $LABEL"
exit 1

