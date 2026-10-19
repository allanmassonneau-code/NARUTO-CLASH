#!/usr/bin/env bash
# Builds a Windows release into build/publish/:
#   NarutoClash-<version>.zip, version.json, NarutoClashLauncher.exe
# Usage: deploy/build_release.sh <version> <public_host> [changelog]
#   GODOT=/path/to/godot (default: godot in PATH)
set -euo pipefail

VERSION="${1:?version required}"
HOST="${2:?public host (VPS IP or domain) required}"
CHANGELOG="${3:-}"
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/publish"
# PUBLIC_URL (e.g. https://ninjabattle.fr/naruto-clash/) overrides the IP URL.
BASE_URL="${PUBLIC_URL:-http://$HOST/naruto-clash/}"

cd "$ROOT"
mkdir -p "$OUT" build/game
find "$OUT" build/game -mindepth 1 -delete

# Stamp the version the server compares on connect.
sed -i "s/^config\/version=.*/config\/version=\"$VERSION\"/" project.godot

"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows Desktop" build/game/NarutoClash.exe
ZIP="NarutoClash-$VERSION.zip"
(cd build/game && zip -q -r "$OUT/$ZIP" .)

# Launcher with the update URL baked in.
sed -i "s|__BASE_URL__|$BASE_URL|" launcher/launcher_config.gd
# Site password (SITE_USER / SITE_PASSWORD) baked into the launcher.
AUTH=""
if [[ -n "${SITE_USER:-}" && -n "${SITE_PASSWORD:-}" ]]; then
  AUTH="$(printf '%s:%s' "$SITE_USER" "$SITE_PASSWORD" | base64 -w0)"
  sed -i "s|__AUTH__|$AUTH|" launcher/launcher_config.gd
fi
"$GODOT" --headless --path launcher --import >/dev/null 2>&1 || true
"$GODOT" --headless --path launcher --export-release "Windows Desktop" ../build/publish/NarutoClashLauncher.exe
sed -i "s|$BASE_URL|__BASE_URL__|" launcher/launcher_config.gd
[[ -z "$AUTH" ]] || sed -i "s|$AUTH|__AUTH__|" launcher/launcher_config.gd

cp "$ROOT/deploy/www/"* "$OUT/"  # download page

SHA="$(sha256sum "$OUT/$ZIP" | cut -d' ' -f1)"
SIZE="$(stat -c %s "$OUT/$ZIP")"
python3 - "$OUT/version.json" "$VERSION" "$ZIP" "$SHA" "$SIZE" "$HOST" "$CHANGELOG" <<'PY'
import json, sys
out, version, file, sha, size, host, changelog = sys.argv[1:]
json.dump({"version": version, "file": file, "sha256": sha, "size": int(size),
           "server_host": host, "changelog": changelog or f"Version {version}"}, open(out, "w"), indent=2)
PY
echo "Release $VERSION ready in $OUT"
ls -la "$OUT"
