#!/usr/bin/env bash
set +e

: "${STREAM_KEY:?Set STREAM_KEY in .env (from YouTube Live)}"
WIDTH="${WIDTH:-1280}"; HEIGHT="${HEIGHT:-720}"; FPS="${FPS:-30}"; BITRATE="${BITRATE:-4500k}"
RTMP="rtmp://a.rtmp.youtube.com/live2/${STREAM_KEY}"
DISPLAY_NUM=99
export DISPLAY=":${DISPLAY_NUM}"
GOP=$((FPS*2))

echo "[0/6] cleaning up stale state from previous run (fixes 'Cannot open display :99' after reboot)"
# kill any leftover processes from a previous (crashed/rebooted) run
pkill -9 Xvfb        >/dev/null 2>&1 || true
pkill -9 chrome      >/dev/null 2>&1 || true
pkill -9 pulseaudio  >/dev/null 2>&1 || true
# remove stale X lock/socket that makes Xvfb refuse to start :99
rm -f  /tmp/.X${DISPLAY_NUM}-lock        >/dev/null 2>&1 || true
rm -f  /tmp/.X11-unix/X${DISPLAY_NUM}    >/dev/null 2>&1 || true
# remove stale pulse runtime dir and chrome singleton locks
rm -rf /tmp/pulse-run                    >/dev/null 2>&1 || true
rm -f  /tmp/chrome-profile/SingletonLock /tmp/chrome-profile/Singleton* >/dev/null 2>&1 || true
sleep 1

echo "[1/6] starting local file server on :8080"
( cd /app && python3 -m http.server 8080 >/dev/null 2>&1 ) &

echo "[2/6] starting virtual display ${WIDTH}x${HEIGHT}"
Xvfb :${DISPLAY_NUM} -screen 0 ${WIDTH}x${HEIGHT}x24 -nolisten tcp >/dev/null 2>&1 &
for i in $(seq 1 30); do
  if xdpyinfo -display :${DISPLAY_NUM} >/dev/null 2>&1; then echo "  display ready"; break; fi
  sleep 0.5
done

echo "[3/6] starting virtual audio (PulseAudio) so Chrome's sound can be captured"
export XDG_RUNTIME_DIR=/tmp/pulse-run
mkdir -p "$XDG_RUNTIME_DIR/pulse"
# start pulse in the foreground-daemon mode with a known socket location
pulseaudio --start --exit-idle-time=-1 --disallow-exit \
  --load="module-native-protocol-unix socket=${XDG_RUNTIME_DIR}/pulse/native" \
  >/tmp/pulse.log 2>&1 || true
# wait until pulse actually answers before loading modules
for i in $(seq 1 20); do
  if pactl info >/dev/null 2>&1; then echo "  pulse ready"; break; fi
  sleep 0.5
done
# a virtual sink that both Chrome plays into and ffmpeg records from
pactl load-module module-null-sink sink_name=streamsink sink_properties=device.description=streamsink >/dev/null 2>&1 || true
pactl set-default-sink streamsink >/dev/null 2>&1 || true
pactl list sources short >/tmp/pulse-sources.log 2>&1 || true

echo "[4/6] launching Chrome (headless-on-Xvfb, software rendering, audio->PulseAudio)"
mkdir -p "/tmp/chrome-profile/Default"
cat > "/tmp/chrome-profile/Default/Preferences" <<'PREFS'
{"translate":{"enabled":false},"translate_blocked_languages":["th","en"],"intl":{"accept_languages":"th,th-TH"},"profile":{"exit_type":"Normal","exited_cleanly":true}}
PREFS

launch_chrome() {
  PULSE_SINK=streamsink google-chrome-stable \
    --no-sandbox --disable-dev-shm-usage --disable-setuid-sandbox \
    --use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader \
    --disable-gpu-compositing \
    --no-first-run --disable-dbus \
    --lang=th --accept-lang=th,th-TH \
    --kiosk --window-position=0,0 --window-size=${WIDTH},${HEIGHT} \
    --autoplay-policy=no-user-gesture-required \
    --hide-scrollbars --disable-infobars \
    --disable-features=Translate,TranslateUI,InfiniteSessionRestore,OptimizationGuideModelDownloading \
    --disable-translate --no-default-browser-check \
    --disable-component-update --disable-search-engine-choice-screen \
    --check-for-update-interval=31536000 \
    --user-data-dir=/tmp/chrome-profile \
    "http://localhost:8080/quake-thailand.html" >/tmp/chromium.log 2>&1
}
( while true; do launch_chrome; echo "chrome exited - relaunching in 3s..."; sleep 3; done ) &

# hide the mouse pointer
( sleep 6; xdotool mousemove 9999 9999 >/dev/null 2>&1 ) &
( unclutter -idle 0 -root >/dev/null 2>&1 ) &

echo "  waiting for the page + map + audio to start..."
sleep 12

echo "[5/6] audio source = Chrome via PulseAudio (falls back to silence if unavailable)"
export PULSE_SERVER="unix:${XDG_RUNTIME_DIR}/pulse/native"
# verify the pulse monitor source actually exists; if not, use silence so ffmpeg never hangs
if pactl list sources short 2>/dev/null | grep -q "streamsink.monitor"; then
  echo "  pulse monitor found -> capturing Chrome audio"
  AUDIO_IN=(-f pulse -thread_queue_size 1024 -i streamsink.monitor)
else
  echo "  pulse monitor NOT found -> streaming silent audio track"
  AUDIO_IN=(-f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100)
fi
AUDIO_MAP=(-map 1:a -c:a aac -b:a 128k -ar 44100)

echo "[6/6] streaming to YouTube - 24/7"
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
