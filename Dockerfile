services:
  quake-stream:
    build: .
    container_name: quake-stream
    restart: always          # survives crashes, reboots, network blips
    env_file: .env
    shm_size: "1gb"          # Chromium needs shared memory
    # no ports exposed — it only pushes OUT to YouTube
