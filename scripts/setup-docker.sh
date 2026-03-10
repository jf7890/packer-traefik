#!/bin/sh

chmod +x /usr/local/bin/proxy-ctl
chmod +x /usr/local/bin/setup

# 1. Install Docker and Compose
echo "[+] Installing Docker..."
apk update
apk add docker docker-cli-compose bash

# 2. Enable Docker service
rc-update add docker default
service docker start

# 3. Wait for Docker daemon
echo "[+] Waiting for Docker daemon..."
i=0
while [ ! -S /var/run/docker.sock ] && [ "$i" -lt 30 ]; do
    echo "."
    sleep 1
    i=$((i + 1))
done
sleep 2

echo "[+] Docker is ready!"

# 4. Ensure project directories exist
mkdir -p /opt/traefik/dynamic_conf
mkdir -p /opt/qdrant/storage

# 5. Pre-pull images so cloned VMs do not wait on downloads
echo "[+] Pre-pulling Docker images..."
cd /opt/traefik
QDRANT_API_KEY=build-time-placeholder docker compose -f /opt/traefik/docker-compose.yml pull

# 6. Cleanup
echo "[+] Cleanup..."
service docker stop
rm -rf /var/cache/apk/*
