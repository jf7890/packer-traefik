#!/bin/bash

# ==============================================================================
# TRAEFIK DYNAMIC CONFIG MANAGER
# ==============================================================================
# Usage:
#   ./manage-proxy.sh add <domain> <url> <verify_tls: true|false>
#   ./manage-proxy.sh add_nginx_dashboard <domain> <frontend_url> <backend_url> <verify_tls: true|false>
#   ./manage-proxy.sh del <domain>
#
# Example:
#   ./manage-proxy.sh add wazuh.local https://172.16.99.11:443 false
#   ./manage-proxy.sh del wazuh.local
# ==============================================================================

# Config directory for yaml files
# For local run before packer build:
# CONFIG_DIR="./files/dynamic_conf"

# For real server (after deploy):
CONFIG_DIR="/opt/traefik/dynamic_conf"

mkdir -p "$CONFIG_DIR"

# Show usage
show_help() {
    echo "Usage: $0 {add|add_nginx_dashboard|del} [arguments]"
    echo ""
    echo "Commands:"
    echo "  add <domain> <target_url> [verify_tls]"
    echo "      domain:     Domain name (e.g., app.local)"
    echo "      target_url: Destination URL (e.g., http://10.0.0.5:8080)"
    echo "      verify_tls: (Optional) true/false. Default: true"
    echo ""
    echo "  add_nginx_dashboard <domain> <frontend_url> <backend_url> [verify_tls]"
    echo "      domain:        Domain name (e.g., app.local)"
    echo "      frontend_url:  Frontend URL (e.g., http://10.0.0.5:8080)"
    echo "      backend_url:   Backend URL for /api (e.g., http://10.0.0.6:3001)"
    echo "      verify_tls:    (Optional) true/false. Default: true"
    echo ""
    echo "  del <domain>"
    echo "      Remove configuration for the specific domain"
    echo ""
    exit 1
}

# Normalize filename from domain (replace dots with underscores)
sanitize_filename() {
    echo "$1" | sed 's/\./_/g'
}

# Ensure scheme (http/https). If only host:port given, default to http.
normalize_url() {
    local url="$1"
    if [[ "$url" != http* ]]; then
        url="http://$url"
    fi
    echo "$url"
}

# ==============================================================================
# MAIN LOGIC
# ==============================================================================

ACTION=$1

if [ -z "$ACTION" ]; then
    show_help
fi

case "$ACTION" in
    "add")
        DOMAIN=$2
        TARGET=$3
        VERIFY_TLS=${4:-true} # Default true if not provided

        if [ -z "$DOMAIN" ] || [ -z "$TARGET" ]; then
            echo "[ERROR] Missing domain or target URL."
            show_help
        fi

        FILENAME=$(sanitize_filename "$DOMAIN")
        FILEPATH="$CONFIG_DIR/${FILENAME}.yml"

        TARGET=$(normalize_url "$TARGET")

        echo "[INFO] Generating config for $DOMAIN -> $TARGET (Verify TLS: $VERIFY_TLS)..."

        # Write YAML
cat > "$FILEPATH" <<EOF
http:
  routers:
    router-${FILENAME}:
      rule: "Host(\`${DOMAIN}\`)"
      service: "service-${FILENAME}"
      entryPoints:
        - "web"

  services:
    service-${FILENAME}:
      loadBalancer:
        servers:
          - url: "${TARGET}"
        serversTransport: "transport-${FILENAME}"

  serversTransports:
    transport-${FILENAME}:
      insecureSkipVerify: $( [ "$VERIFY_TLS" == "false" ] && echo "true" || echo "false" )
EOF

        echo "[SUCCESS] Created config at: $FILEPATH"
        ;;

    "add_nginx_dashboard")
        DOMAIN=$2
        FRONTEND=$3
        BACKEND=$4
        VERIFY_TLS=${5:-true} # Default true if not provided

        if [ -z "$DOMAIN" ] || [ -z "$FRONTEND" ] || [ -z "$BACKEND" ]; then
            echo "[ERROR] Missing domain, frontend URL, or backend URL."
            show_help
        fi

        FILENAME=$(sanitize_filename "$DOMAIN")
        FILEPATH="$CONFIG_DIR/${FILENAME}.yml"

        FRONTEND=$(normalize_url "$FRONTEND")
        BACKEND=$(normalize_url "$BACKEND")

        echo "[INFO] Generating config for $DOMAIN -> frontend $FRONTEND, backend $BACKEND (Verify TLS: $VERIFY_TLS)..."

cat > "$FILEPATH" <<EOF
http:
  routers:
    router-${FILENAME}-api:
      rule: "Host(\`${DOMAIN}\`) && PathPrefix(\`/api\`)"
      service: "service-${FILENAME}-api"
      entryPoints:
        - "web"
      priority: 100

    router-${FILENAME}:
      rule: "Host(\`${DOMAIN}\`)"
      service: "service-${FILENAME}"
      entryPoints:
        - "web"
      priority: 1

  services:
    service-${FILENAME}:
      loadBalancer:
        servers:
          - url: "${FRONTEND}"
        serversTransport: "transport-${FILENAME}"

    service-${FILENAME}-api:
      loadBalancer:
        servers:
          - url: "${BACKEND}"
        serversTransport: "transport-${FILENAME}"

  serversTransports:
    transport-${FILENAME}:
      insecureSkipVerify: $( [ "$VERIFY_TLS" == "false" ] && echo "true" || echo "false" )
EOF

        echo "[SUCCESS] Created config at: $FILEPATH"
        ;;

    "del")
        DOMAIN=$2
        if [ -z "$DOMAIN" ]; then
            echo "[ERROR] Missing domain to delete."
            show_help
        fi

        FILENAME=$(sanitize_filename "$DOMAIN")
        FILEPATH="$CONFIG_DIR/${FILENAME}.yml"

        if [ -f "$FILEPATH" ]; then
            rm "$FILEPATH"
            echo "[SUCCESS] Deleted config for domain: $DOMAIN"
        else
            echo "[WARNING] Config file for '$DOMAIN' not found at $FILEPATH"
        fi
        ;;

    *)
        echo "[ERROR] Unknown command: $ACTION"
        show_help
        ;;
esac
