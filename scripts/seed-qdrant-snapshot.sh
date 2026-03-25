#!/bin/sh

set -eu

PROJECT_DIR="/opt/traefik"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
DOWNLOAD_DIR="/opt/qdrant/bootstrap"
QDRANT_URL="http://127.0.0.1:6333"
QDRANT_API_KEY="${QDRANT_BUILD_API_KEY:-build-time-placeholder}"
SNAPSHOT_URL="https://raw.githubusercontent.com/jf7890/qdrant_snapshot/main/waf_payloads_jina-2026-03-22.snapshot"
COLLECTION_NAME="waf_payloads_jina"
SNAPSHOT_CHECKSUM="60A523614F6E090C7A38A31E3C9CB869D43B03BBFFD667698814B4F0DC60473A"
SNAPSHOT_FILE_NAME=""
DOWNLOAD_PATH=""
DOCKER_WAS_STARTED=0
DOCKER_SERVICE_STARTED=0

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

wait_for_qdrant() {
    i=0
    while [ "$i" -lt 60 ]; do
        if curl -fsS -H "api-key: $QDRANT_API_KEY" "$QDRANT_URL/collections" >/dev/null 2>&1; then
            return 0
        fi

        sleep 2
        i=$((i + 1))
    done

    echo "[ERROR] Qdrant API did not become ready in time."
    exit 1
}

wait_for_collection() {
    i=0
    while [ "$i" -lt 60 ]; do
        if curl -fsS -H "api-key: $QDRANT_API_KEY" "$QDRANT_URL/collections/$COLLECTION_NAME" >/dev/null 2>&1; then
            return 0
        fi

        sleep 2
        i=$((i + 1))
    done

    echo "[ERROR] Collection '$COLLECTION_NAME' was not available after snapshot upload."
    exit 1
}

cleanup() {
    if [ "$DOCKER_WAS_STARTED" -eq 1 ]; then
        QDRANT_API_KEY="$QDRANT_API_KEY" docker compose -f "$COMPOSE_FILE" down >/dev/null 2>&1 || true
    fi

    if [ "$DOCKER_SERVICE_STARTED" -eq 1 ]; then
        service docker stop >/dev/null 2>&1 || true
    fi

    if [ -n "$DOWNLOAD_PATH" ] && [ -f "$DOWNLOAD_PATH" ]; then
        rm -f "$DOWNLOAD_PATH"
    fi
}

trap cleanup EXIT

if [ -z "$SNAPSHOT_FILE_NAME" ]; then
    SNAPSHOT_FILE_NAME=$(basename "${SNAPSHOT_URL%%\?*}")
fi

if [ -z "$SNAPSHOT_FILE_NAME" ]; then
    SNAPSHOT_FILE_NAME="${COLLECTION_NAME}.snapshot"
fi

mkdir -p "$DOWNLOAD_DIR" /opt/qdrant/storage
DOWNLOAD_PATH="$DOWNLOAD_DIR/$SNAPSHOT_FILE_NAME"

echo "[+] Downloading Qdrant snapshot from $SNAPSHOT_URL..."
curl -fL --retry 3 --retry-delay 2 "$SNAPSHOT_URL" -o "$DOWNLOAD_PATH"

if [ -n "$SNAPSHOT_CHECKSUM" ]; then
    echo "[+] Verifying snapshot checksum..."
    printf '%s  %s\n' "$SNAPSHOT_CHECKSUM" "$DOWNLOAD_PATH" | sha256sum -c -
fi

echo "[+] Starting Docker for Qdrant seed..."
service docker start >/dev/null 2>&1 || true
DOCKER_SERVICE_STARTED=1
wait_for_docker

echo "[+] Starting Qdrant service..."
cd "$PROJECT_DIR"
QDRANT_API_KEY="$QDRANT_API_KEY" docker compose -f "$COMPOSE_FILE" up -d qdrant
DOCKER_WAS_STARTED=1

echo "[+] Waiting for Qdrant API..."
wait_for_qdrant

RESTORE_URL="$QDRANT_URL/collections/$COLLECTION_NAME/snapshots/upload?priority=snapshot"
if [ -n "$SNAPSHOT_CHECKSUM" ]; then
    RESTORE_URL="$RESTORE_URL&checksum=$SNAPSHOT_CHECKSUM"
fi

echo "[+] Restoring collection '$COLLECTION_NAME' from uploaded snapshot..."
curl -fsS -X POST \
    -H "api-key: $QDRANT_API_KEY" \
    -F "snapshot=@$DOWNLOAD_PATH" \
    "$RESTORE_URL" >/dev/null

echo "[+] Verifying restored collection..."
wait_for_collection

echo "[OK] Qdrant collection '$COLLECTION_NAME' restored into template storage."
