#!/bin/sh

set -eu

PROJECT_DIR="/opt/traefik"
ENV_FILE="$PROJECT_DIR/.env"
START_SCRIPT="/etc/local.d/docker-compose.start"

show_help() {
    echo "Usage: setup <QDRANT_API_KEY>"
    exit 1
}

wait_for_docker() {
    i=0
    while [ ! -S /var/run/docker.sock ] && [ "$i" -lt 30 ]; do
        sleep 1
        i=$((i + 1))
    done

    if [ ! -S /var/run/docker.sock ]; then
        echo "[ERROR] Docker daemon is not ready."
        exit 1
    fi
}

if [ "$#" -ne 1 ]; then
    show_help
fi

API_KEY="$1"
CR=$(printf '\r')

if [ -z "$API_KEY" ]; then
    echo "[ERROR] API key must not be empty."
    exit 1
fi

case "$API_KEY" in
    *"$CR"*)
        echo "[ERROR] API key must be a single line."
        exit 1
        ;;
esac

mkdir -p "$PROJECT_DIR" /opt/qdrant/storage /etc/local.d

echo "[+] Ensuring Docker starts on boot..."
rc-update add docker default >/dev/null 2>&1 || true

echo "[+] Starting Docker..."
service docker start >/dev/null 2>&1 || true
wait_for_docker

echo "[+] Writing $ENV_FILE..."
umask 077
printf 'QDRANT_API_KEY=%s\n' "$API_KEY" > "$ENV_FILE"

echo "[+] Enabling compose start on boot..."
cat > "$START_SCRIPT" <<'EOF'
#!/bin/sh
while [ ! -S /var/run/docker.sock ]; do sleep 1; done
cd /opt/traefik
docker compose up -d
EOF

chmod +x "$START_SCRIPT"
rc-update add local default >/dev/null 2>&1 || true

echo "[+] Starting Traefik stack..."
cd "$PROJECT_DIR"
docker compose up -d

echo "[OK] Stack started. Re-run 'setup <API_KEY>' to rotate the Qdrant API key."
