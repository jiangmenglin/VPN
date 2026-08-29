#!/bin/bash

set -e

IMAGE_NAME="vpn"
CONTAINER_NAME="vpn-container"
DEFAULT_PORT=8080

print_usage() {
    echo "Usage: $0 -p <password> [-P <port>] [-D <domain>] [-r <path>] [-g <git-url>]"
    echo "  -p <password>   Required: VPN password"
    echo "  -P <port>       Optional: host port (default: $DEFAULT_PORT)"
    echo "  -D <domain>     Optional: domain for TLS mode (default: no)"
    echo "  -r <path>       Optional: path to VPN project directory"
    echo "  -g <git-url>    Optional: git clone URL (e.g. https://github.com/aditya-shri/VPN.git)"
    echo "  -h              Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 -p mypass -r ./VPN"
    echo "  $0 -p mypass -g https://github.com/aditya-shri/VPN.git"
    exit 1
}

PORT=$DEFAULT_PORT
DOMAIN="no"
PASSWORD=""
PROJECT_DIR=""
GIT_URL=""

while getopts "p:P:D:r:g:h" opt; do
    case $opt in
        p) PASSWORD="$OPTARG" ;;
        P) PORT="$OPTARG" ;;
        D) DOMAIN="$OPTARG" ;;
        r) PROJECT_DIR="$OPTARG" ;;
        g) GIT_URL="$OPTARG" ;;
        h) print_usage ;;
        *) print_usage ;;
    esac
done

if [ -z "$PASSWORD" ]; then
    echo "Error: password is required (-p)"
    print_usage
fi

cleanup() {
    [ -n "$TMP_DIR" ] && rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ -n "$GIT_URL" ]; then
    TMP_DIR=$(mktemp -d)
    echo ">>> Cloning from $GIT_URL ..."
    git clone "$GIT_URL" "$TMP_DIR"
    PROJECT_DIR="$TMP_DIR"
elif [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
    echo ">>> Using current directory: $PROJECT_DIR"
fi

if [ ! -f "$PROJECT_DIR/Dockerfile" ]; then
    echo "Error: Dockerfile not found in $PROJECT_DIR"
    exit 1
fi

if ! command -v docker &>/dev/null; then
    echo ">>> Docker not found, installing..."
    sudo apt update && sudo apt install -y docker.io
    sudo systemctl enable --now docker
fi

if ! command -v git &>/dev/null; then
    echo ">>> Git not found, installing..."
    sudo apt install -y git
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
