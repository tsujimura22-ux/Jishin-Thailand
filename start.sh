#!/usr/bin/env bash
set -e

: "${STREAM_KEY:?Set STREAM_KEY in .env (from YouTube Live)}"
WIDTH="${WIDTH:-1280}"; HEIGHT="${HEIGHT:-720}"; FPS="${FPS:-30}"; BITRATE="${BITRATE:-4500k}"
RTMP="rtmp://a.rtmp.youtube.com/live2/${STREAM_KEY}"
DISPLAY_NUM=99
export DISPLAY=":${DISPLAY_NUM}"

echo "[1/5] starting local file server on :8080"
( cd /app && python3 -m http.server 8080 >/dev/null 2>&1 ) &

echo "[2/5] starting virtual display ${WIDTH}x${HEIGHT}"
Xvfb :${DISPLAY_NUM} -screen 0 ${WIDTH}x${HEIGHT}x24 -nolisten tcp >/dev/null 2>&1 &
sleep 3

echo "[3/5] launching Chromium (headless-on-Xvfb, fullscreen kiosk)"
chromium-browser \
  --no-sandbox --disable-gpu --disable-dev-shm-usage \
  --kiosk --window-position=0,0 --window-size=${WIDTH},${HEIGHT} \
  --autoplay-policy=no-user-gesture-required \
  --hide-scrollbars --disable-infobars --check-for-update-interval=31536000 \
  "http://localhost:8080/quake-thailand.html" >/dev/null 2>&1 &
sleep 6   # let the map + USGS data load before we start broadcasting

echo "[4/5] preparing audio source (${AUDIO})"
# Ambient bed so YouTube isn't silent. Replace bgm.mp3 in /app to use your own track.
if [ -f /app/bgm.mp3 ]; then
  AUDIO_IN=(-stream_loop -1 -i /app/bgm.mp3)
  AUDIO_MAP=(-map 1:a -c:a aac -b:a 128k -ar 44100)
else
  # silent-but-valid AAC track (YouTube requires an audio stream)
  AUDIO_IN=(-f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100)
  AUDIO_MAP=(-map 1:a -c:a aac -b:a 128k)
fi

echo "[5/5] streaming to YouTube — 24/7"
# loop forever: if ffmpeg ever exits, restart after 5s (network blips, etc.)
while true; do
  ffmpeg -nostdin \
    -f x11grab -framerate ${FPS} -video_size ${WIDTH}x${HEIGHT} -i :${DISPLAY_NUM} \
    "${AUDIO_IN[@]}" \
    -map 0:v "${AUDIO_MAP[@]}" \
    -c:v libx264 -preset veryfast -tune zerolatency -pix_fmt yuv420p \
    -b:v ${BITRATE} -maxrate ${BITRATE} -bufsize $((${BITRATE%k}*2))k \
    -g $((FPS*2)) -keyint_min ${FPS} \
    -f flv "${RTMP}" || true
  echo "ffmpeg exited — restarting in 5s..."
  sleep 5
done
