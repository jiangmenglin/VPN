#!/bin/bash

set -e

IMAGE_NAME="vpn"
CONTAINER_NAME="vpn-container"
DEFAULT_PORT=8080

print_usage() {
    echo "Usage: $0 -p <password> [-P <port>] [-D <domain>] [-r <path>]"
    echo "  -p <password>   Required: VPN password"
    echo "  -P <port>       Optional: host port (default: $DEFAULT_PORT)"
    echo "  -D <domain>     Optional: domain for TLS mode (default: no)"
    echo "  -r <path>       Optional: path to VPN project directory (default: current directory via pwd)"
    echo "  -h              Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 -p mypass"
    echo "  $0 -p mypass -r /root/VPN"
    exit 1
}

PORT=$DEFAULT_PORT
DOMAIN="no"
PASSWORD=""
PROJECT_DIR=""

while getopts "p:P:D:r:h" opt; do
    case $opt in
        p) PASSWORD="$OPTARG" ;;
        P) PORT="$OPTARG" ;;
        D) DOMAIN="$OPTARG" ;;
        r) PROJECT_DIR="$OPTARG" ;;
        h) print_usage ;;
        *) print_usage ;;
    esac
done

if [ -z "$PASSWORD" ]; then
    echo "Error: password is required (-p)"
    print_usage
fi

if [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR="$(pwd)"
fi
echo ">>> Using project directory: $PROJECT_DIR"

if [ ! -f "$PROJECT_DIR/Dockerfile" ]; then
    echo "Error: Dockerfile not found in $PROJECT_DIR"
    exit 1
fi

if ! command -v docker &>/dev/null; then
    echo ">>> Docker not found, installing..."
    sudo apt update && sudo apt install -y docker.io
    sudo systemctl enable --now docker
fi

echo ">>> Building Docker image..."
sudo docker build -t "$IMAGE_NAME" "$PROJECT_DIR"

echo ">>> Stopping and removing existing container if any..."
sudo docker stop "$CONTAINER_NAME" 2>/dev/null || true
sudo docker rm "$CONTAINER_NAME" 2>/dev/null || true

echo ">>> Running container on port $PORT..."
sudo docker run -d \
    -p "$PORT:80" \
    -e Password="$PASSWORD" \
    -e PORT=80 \
    -e Domain="$DOMAIN" \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME"

echo ">>> Container started successfully!"
echo "    VPN running on port $PORT"
echo "    Password: $PASSWORD"
echo ""
echo "Run 'sudo docker logs $CONTAINER_NAME' to check status."
