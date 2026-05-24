#!/usr/bin/env bash
# update.sh — pull latest from GitHub and refresh the live stream
# usage:  ./update.sh
set -e

echo "▶ [1/4] pulling latest from GitHub..."
git pull --rebase --autostash

echo "▶ [2/4] placing files into app/ ..."
mkdir -p app
# move/copy the runtime files into app/ (where the container serves them)
[ -f quake-thailand.html ] && cp -f quake-thailand.html app/
[ -f thai-provinces.geojson ] && cp -f thai-provinces.geojson app/ 2>/dev/null || true

echo "▶ [3/4] restarting the stream container..."
# if the image needs rebuilding (Dockerfile/deps changed), use: docker compose up -d --build
docker compose restart || docker compose up -d

echo "▶ [4/4] done. Recent logs:"
sleep 2
docker compose logs --tail 15

echo ""
echo "✅ updated & restarted. The YouTube stream will refresh within ~30s."
