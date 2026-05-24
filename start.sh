#!/usr/bin/env bash
set -e

: "${STREAM_KEY:?Set STREAM_KEY in .env (from YouTube Live)}"
WIDTH="${WIDTH:-1280}"; HEIGHT="${HEIGHT:-720}"; FPS="${FPS:-30}"; BITRATE="${BITRATE:-4500k}"
RTMP="rtmp://a.rtmp.youtube.com/live2/${STREAM_KEY}"
DISPLAY_NUM=99
export DISPLAY=":${DISPLAY_NUM}"
GOP=$((FPS*2))

echo "[1/5] starting local file server on :8080"
( cd /app && python3 -m http.server 8080 >/dev/null 2>&1 ) &

echo "[2/5] starting virtual display ${WIDTH}x${HEIGHT}"
Xvfb :${DISPLAY_NUM} -screen 0 ${WIDTH}x${HEIGHT}x24 -nolisten tcp >/dev/null 2>&1 &
for i in $(seq 1 30); do
  if xdpyinfo -display :${DISPLAY_NUM} >/dev/null 2>&1; then echo "  display ready"; break; fi
  sleep 0.5
done

echo "[3/5] launching Chromium (headless-on-Xvfb, software rendering)"
launch_chromium() {
  chromium-browser \
    --no-sandbox --disable-dev-shm-usage \
    --use-gl=swiftshader --enable-unsafe-swiftshader \
    --disable-gpu-compositing --in-process-gpu \
    --kiosk --window-position=0,0 --window-size=${WIDTH},${HEIGHT} \
    --autoplay-policy=no-user-gesture-required \
    --hide-scrollbars --disable-infobars --disable-translate \
    --check-for-update-interval=31536000 \
    --user-data-dir=/tmp/chrome-profile \
    "http://localhost:8080/quake-thailand.html" >/tmp/chromium.log 2>&1
}
( while true; do launch_chromium; echo "chromium exited - relaunching in 3s..."; sleep 3; done ) &

echo "  waiting for the page + map to render..."
sleep 12

echo "[4/5] preparing audio source (ambient)"
if [ -f /app/bgm.mp3 ]; then
  AUDIO_IN=(-stream_loop -1 -i /app/bgm.mp3)
  AUDIO_MAP=(-map 1:a -c:a aac -b:a 128k -ar 44100)
else
  AUDIO_IN=(-f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100)
  AUDIO_MAP=(-map 1:a -c:a aac -b:a 128k)
fi

echo "[5/5] streaming to YouTube - 24/7"
while true; do
  ffmpeg -nostdin \
    -f x11grab -framerate ${FPS} -video_size ${WIDTH}x${HEIGHT} \
    -thread_queue_size 512 -i :${DISPLAY_NUM} \
    "${AUDIO_IN[@]}" \
    -map 0:v "${AUDIO_MAP[@]}" \
    -c:v libx264 -preset veryfast -tune zerolatency -pix_fmt yuv420p \
    -b:v ${BITRATE} -maxrate ${BITRATE} -bufsize 9000k \
    -g ${GOP} -keyint_min ${FPS} \
    -f flv "${RTMP}" || true
  echo "ffmpeg exited - restarting in 5s..."
  sleep 5
done
