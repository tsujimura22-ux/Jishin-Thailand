FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Chromium, virtual display, ffmpeg, a tiny static file server, fonts (incl. Thai)
RUN apt-get update && apt-get install -y --no-install-recommends \
      chromium-browser xvfb x11-utils \
      ffmpeg \
      fonts-noto-core fonts-noto-cjk fonts-noto-color-emoji fonts-thai-tlwg \
      python3 ca-certificates dbus \
    && rm -rf /var/lib/apt/lists/*

# App files (the monitor + province data) served locally so the stream never depends on a public host
WORKDIR /app
COPY app/ /app/

COPY start.sh /start.sh
RUN chmod +x /start.sh

# Stream key & options are passed via environment (.env)
ENV WIDTH=1280 HEIGHT=720 FPS=30 BITRATE=4500k AUDIO=ambient
ENTRYPOINT ["/start.sh"]
