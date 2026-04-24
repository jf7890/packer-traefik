#!/bin/sh

set -eu

PROJECT_DIR="/opt/traefik"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
DOWNLOAD_DIR="/opt/qdrant/bootstrap"
CONTAINER_SNAPSHOT_DIR="/qdrant/snapshots"
QDRANT_URL="http://127.0.0.1:6333"
QDRANT_API_KEY="${QDRANT_BUILD_API_KEY:-build-time-placeholder}"
SNAPSHOT_URL="https://github.com/jf7890/qdrant_snapshot/raw/refs/heads/main/waf_payloads_jina-2026-03-22.snapshot"
COLLECTION_NAME="waf_payloads"
SNAPSHOT_FILE_NAME=""
CHECKSUM_URL=""
SNAPSHOT_CHECKSUM=""
DOWNLOAD_PATH=""
CONTAINER_SNAPSHOT_PATH=""
CHECKSUM_FILE="/tmp/qdrant-snapshot-checksum.txt"
RESTORE_RESPONSE_FILE="/tmp/qdrant-restore-response.json"
WORK_DIR=""
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

    echo "[ERROR] Collection '$COLLECTION_NAME' was not available after snapshot restore."
    exit 1
}

resolve_snapshot_checksum() {
    echo "[+] Looking for snapshot checksum at $CHECKSUM_URL..."
    if ! curl -fsSL --retry 3 --retry-delay 2 "$CHECKSUM_URL" -o "$CHECKSUM_FILE" 2>/dev/null; then
        echo "[!] No CHECKSUM file found. Skipping checksum verification."
        return 0
    fi

    SNAPSHOT_CHECKSUM=$(
        awk -v file="$SNAPSHOT_FILE_NAME" '
            {
                gsub(/\r$/, "", $0)
            }

            /^[[:space:]]*#/ || /^[[:space:]]*$/ {
                next
            }

            index($0, ":") > 0 {
                name = substr($0, 1, index($0, ":") - 1)
                checksum = substr($0, index($0, ":") + 1)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", checksum)
                if (name == file) {
                    print checksum
                    exit
                }
            }

            {
                line = $0
                sub(/^[[:space:]]+/, "", line)
                split(line, parts, /[[:space:]]+/)
                if (length(parts[1]) > 0 && parts[2] == file) {
                    print parts[1]
                    exit
                }
            }
        ' "$CHECKSUM_FILE"
    )

    if [ -n "$SNAPSHOT_CHECKSUM" ]; then
        echo "[+] Loaded checksum for $SNAPSHOT_FILE_NAME from CHECKSUM file."
    else
        echo "[!] No checksum entry for $SNAPSHOT_FILE_NAME. Skipping checksum verification."
    fi
}

normalize_tar_archive() {
    archive_path="$1"
    extract_dir="$2"

    rm -rf "$extract_dir"
    mkdir -p "$extract_dir"
    tar -xf "$archive_path" -C "$extract_dir"
}

repack_directory_to_tar() {
    source_dir="$1"
    target_path="$2"

    rm -f "$target_path"
    (
        cd "$source_dir"
        set -- *
        tar --format=posix -cf "$target_path" "$@"
    )
}

normalize_snapshot_archive() {
    WORK_DIR=$(mktemp -d "$DOWNLOAD_DIR/qdrant-snapshot.XXXXXX")
    OUTER_DIR="$WORK_DIR/original"
    INNER_BASE_DIR="$WORK_DIR/segments"
    NORMALIZED_PATH="$WORK_DIR/normalized.snapshot"

    echo "[+] Normalizing snapshot tar format for Qdrant compatibility..."
    normalize_tar_archive "$DOWNLOAD_PATH" "$OUTER_DIR"

    if [ -d "$OUTER_DIR/0/segments" ]; then
        for segment_tar in "$OUTER_DIR"/0/segments/*.tar; do
            [ -f "$segment_tar" ] || continue

            segment_name=$(basename "$segment_tar" .tar)
            segment_dir="$INNER_BASE_DIR/$segment_name"
            segment_repacked="$INNER_BASE_DIR/$segment_name.tar"

            mkdir -p "$INNER_BASE_DIR"
            normalize_tar_archive "$segment_tar" "$segment_dir"
            repack_directory_to_tar "$segment_dir" "$segment_repacked"
            mv "$segment_repacked" "$segment_tar"
        done
    fi

    repack_directory_to_tar "$OUTER_DIR" "$NORMALIZED_PATH"

    mv "$NORMALIZED_PATH" "$DOWNLOAD_PATH"
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

    if [ -f "$CHECKSUM_FILE" ]; then
        rm -f "$CHECKSUM_FILE"
    fi

    if [ -f "$RESTORE_RESPONSE_FILE" ]; then
        rm -f "$RESTORE_RESPONSE_FILE"
    fi

    if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
        rm -rf "$WORK_DIR"
    fi
}

trap cleanup EXIT

if [ -z "$SNAPSHOT_FILE_NAME" ]; then
    SNAPSHOT_FILE_NAME=$(basename "${SNAPSHOT_URL%%\?*}")
fi

if [ -z "$SNAPSHOT_FILE_NAME" ]; then
    SNAPSHOT_FILE_NAME="${COLLECTION_NAME}.snapshot"
fi

CHECKSUM_URL="${SNAPSHOT_URL%/*}/CHECKSUM"

mkdir -p "$DOWNLOAD_DIR" /opt/qdrant/storage
DOWNLOAD_PATH="$DOWNLOAD_DIR/$SNAPSHOT_FILE_NAME"
CONTAINER_SNAPSHOT_PATH="$CONTAINER_SNAPSHOT_DIR/$SNAPSHOT_FILE_NAME"

echo "[+] Downloading Qdrant snapshot from $SNAPSHOT_URL..."
curl -fL --retry 3 --retry-delay 2 "$SNAPSHOT_URL" -o "$DOWNLOAD_PATH"

resolve_snapshot_checksum

if [ -n "$SNAPSHOT_CHECKSUM" ]; then
    echo "[+] Verifying snapshot checksum..."
    printf '%s  %s\n' "$SNAPSHOT_CHECKSUM" "$DOWNLOAD_PATH" | sha256sum -c -
fi

normalize_snapshot_archive

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

RESTORE_URL="$QDRANT_URL/collections/$COLLECTION_NAME/snapshots/recover?wait=true"

echo "[+] Restoring collection '$COLLECTION_NAME' from snapshot file..."
HTTP_STATUS=$(
    cat <<EOF | curl -sS -o "$RESTORE_RESPONSE_FILE" -w "%{http_code}" -X PUT \
        -H "api-key: $QDRANT_API_KEY" \
        -H "Content-Type: application/json" \
        "$RESTORE_URL" \
        --data-binary @-
{
  "location": "file://$CONTAINER_SNAPSHOT_PATH",
  "priority": "snapshot"
}
EOF
)

if [ "$HTTP_STATUS" -lt 200 ] || [ "$HTTP_STATUS" -ge 300 ]; then
    echo "[ERROR] Qdrant restore failed with HTTP $HTTP_STATUS."
    if [ -f "$RESTORE_RESPONSE_FILE" ]; then
        cat "$RESTORE_RESPONSE_FILE"
        echo
    fi
    exit 1
fi

echo "[+] Verifying restored collection..."
wait_for_collection

echo "[OK] Qdrant collection '$COLLECTION_NAME' restored into template storage."
