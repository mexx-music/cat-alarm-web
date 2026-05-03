#!/usr/bin/env bash
set -euo pipefail

# tools/build_bundle_to_desktop.sh
# Erstellt ein Release App Bundle und kopiert es auf den Desktop mit einem versionierten Dateinamen.
# Usage: ./tools/build_bundle_to_desktop.sh

# Wechsle ins Repo-Root (Verzeichnis zwei Ebenen über diesem Script)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Projekt-Root: $ROOT_DIR"

# 1) Version aus pubspec.yaml auslesen (Format: 1.0.5+6)
version_raw=""
if [ -f pubspec.yaml ]; then
  # robuster: nimm die rechte Seite nach 'version: ' und entferne Quotes
  version_raw=$(awk -F': ' '/^version:/{print $2; exit}' pubspec.yaml | tr -d '"' | tr -d "'" ) || true
fi

if [ -z "$version_raw" ]; then
  version_name="unknown"
  version_code="unknown"
else
  if [[ "$version_raw" == *+* ]]; then
    version_name="${version_raw%%+*}"
    version_code="${version_raw##*+}"
  else
    version_name="$version_raw"
    version_code="unknown"
  fi
fi

echo "Version gefunden: $version_name (code: $version_code)"

# 2) Flutter-Aufräumen & Abhängigkeiten
echo "=> flutter clean"
flutter clean

echo "=> flutter pub get"
flutter pub get

# 3) AppBundle bauen
echo "=> flutter build appbundle (Release)"
if ! flutter build appbundle --release; then
  echo "❌ Build fehlgeschlagen: flutter build appbundle returned non-zero exit code"
  exit 1
fi

# 4) Erwartete AAB-Pfade prüfen
CANDIDATES=(
  "build/app/outputs/bundle/release/app-release.aab"
  "build/app/outputs/bundle/release/app.aab"
  "build/app/outputs/bundle/release/app-releasebundle.aab"
)

FOUND=""
for p in "${CANDIDATES[@]}"; do
  if [ -f "$p" ]; then
    FOUND="$p"
    break
  fi
done

if [ -z "$FOUND" ]; then
  echo "❌ Build war erfolgreich, aber die AAB-Datei wurde nicht an den erwarteten Orten gefunden."
  echo "Prüfe: build/app/outputs/bundle/release/"
  ls -la build/app/outputs/bundle/release/ || true
  exit 2
fi

# 5) Zielpfad auf Desktop zusammenbauen
DEST="$HOME/Desktop/cat_alarm_${version_name}_build${version_code}.aab"

# Falls bereits vorhanden, ggf. überschreiben (sicherheitsfrage kann hier angepasst werden)
cp "$FOUND" "$DEST"
chmod 644 "$DEST" || true

echo "✅ Bundle kopiert nach $DEST"
exit 0
