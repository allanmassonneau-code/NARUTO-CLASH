#!/usr/bin/env bash
# Publishes a release to the VPS (after deploy/build_release.sh):
#   - game server code -> /opt/naruto-clash/server (then restarts both servers);
#     the converted SS assets (_ss_local) stay out: the headless server never
#     renders them and importing them would exceed the service start timeout

#   - build/publish/*  -> /var/www/naruto-clash (launcher downloads)
# Usage: deploy/deploy.sh <host> [user=deploy]     (SSH key must be loaded)
set -euo pipefail

HOST="${1:?host required}"
USER_NAME="${2:-deploy}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSH_OPTS="-o StrictHostKeyChecking=accept-new"
TARGET="$USER_NAME@$HOST"

cd "$ROOT"
[[ -f build/publish/version.json ]] || { echo "Run deploy/build_release.sh first."; exit 1; }

rsync -az --delete --chmod=Dg+rwxs,Fg+rw -e "ssh $SSH_OPTS" \
  --exclude ".git" --exclude ".godot" --exclude "build" --exclude "launcher" \
  --exclude "tests" --exclude "tools" --exclude "deploy" --exclude ".github" \
  --exclude "_ss_local" \
  ./ "$TARGET:/opt/naruto-clash/server/"

# Archive + launcher first, manifest last so clients never see a half-published release.
rsync -az -e "ssh $SSH_OPTS" --exclude version.json build/publish/ "$TARGET:/var/www/naruto-clash/"
rsync -az -e "ssh $SSH_OPTS" build/publish/version.json "$TARGET:/var/www/naruto-clash/version.json"

ssh $SSH_OPTS "$TARGET" "sudo systemctl restart naruto-server@1v1 && sudo systemctl restart naruto-server@2v2"
echo "Deployed $(python3 -c 'import json;print(json.load(open("build/publish/version.json"))["version"])') to $HOST"
