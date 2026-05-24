#!/usr/bin/env bash
# deploy.sh — full (re)build & start. Use on first launch, or after Dockerfile/deps change.
# usage:  ./deploy.sh
set -e

echo "▶ [1/4] pulling latest from GitHub..."
git pull --rebase --autostash 2>/dev/null || true

echo "▶ [2/4] placing files into app/ ..."
mkdir -p app
[ -f quake-thailand.html ] && cp -f quake-thailand.html app/
[ -f thai-provinces.geojson ] && cp -f thai-provinces.geojson app/ 2>/dev/null || true

if [ ! -f .env ]; then
  echo "⚠ .env not found. Create it first:"
  echo "    cp .env.example .env && nano .env   (paste your STREAM_KEY)"
  exit 1
fi

echo "▶ [3/4] building & starting (this can take a few minutes the first time)..."
docker compose up -d --build

echo "▶ [4/4] done. Recent logs:"
sleep 3
docker compose logs --tail 20

echo ""
echo "✅ deployed. Check YouTube Studio — the live preview should appear within ~30–60s."
