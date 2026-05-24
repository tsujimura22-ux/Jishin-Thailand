FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Base tools: virtual display, ffmpeg, static file server, fonts (incl. Thai), and deps for Chrome
RUN apt-get update && apt-get install -y --no-install-recommends \
      xvfb x11-utils \
      ffmpeg \
      fonts-noto-core fonts-noto-cjk fonts-noto-color-emoji fonts-thai-tlwg \
      python3 ca-certificates dbus wget gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install Google Chrome (stable) directly via .deb — works in containers (no snap needed)
RUN wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/chrome.deb \
    && rm -f /tmp/chrome.deb \
    && rm -rf /var/lib/apt/lists/*

# App files (the monitor + province data) served locally so the stream never depends on a public host
WORKDIR /app
COPY app/ /app/

COPY start.sh /start.sh
RUN chmod +x /start.sh

# Stream key & options are passed via environment (.env)
ENV WIDTH=1280 HEIGHT=720 FPS=30 BITRATE=4500k AUDIO=ambient
ENTRYPOINT ["/start.sh"]
