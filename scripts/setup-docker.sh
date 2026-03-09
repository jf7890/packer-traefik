#!/bin/sh

chmod +x /usr/local/bin/proxy-ctl

# 1. Install Docker and Compose
echo "[+] Installing Docker..."
apk update
apk add docker docker-cli-compose bash

# 2. Enable Docker service
rc-update add docker default
service docker start

# --- WAIT FOR DOCKER READY ---
echo "[+] Waiting for Docker daemon..."
i=0
while [ ! -S /var/run/docker.sock ] && [ $i -lt 30 ]; do
    echo "."
    sleep 1
    i=$((i+1))
done
sleep 2

echo "[+] Docker is ready!"

# 3. Ensure project directories exist
mkdir -p /opt/traefik/dynamic_conf
mkdir -p /opt/qdrant/storage

# 3.1 Pre-pull images so cloned VMs don't wait on downloads
echo "[+] Pre-pulling Docker images..."
cd /opt/traefik
docker compose -f /opt/traefik/docker-compose.yml pull

# 4. Configure auto-start
echo "[+] Configuring Auto-start..."
cat > /etc/local.d/docker-compose.start <<EOF
#!/bin/sh
while [ ! -S /var/run/docker.sock ]; do sleep 1; done
cd /opt/traefik
docker compose up -d
EOF

chmod +x /etc/local.d/docker-compose.start
rc-update add local default

# 5. Cleanup
echo "[+] Cleanup..."
service docker stop
rm -rf /var/cache/apk/*
