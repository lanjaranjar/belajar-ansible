#!/bin/bash

# ============================================
# Remote Docker Container Manager
# Usage:
#   ./docker_manager.sh stop                    # Stop all (interactive password)
#   ./docker_manager.sh start                   # Start all (interactive password)
#   ./docker_manager.sh status                  # Check status (interactive password)
#   ./docker_manager.sh stop -p mypassword      # Stop all (auto password via sshpass)
#   ./docker_manager.sh start -p mypassword     # Start all (auto password via sshpass)
#   ./docker_manager.sh status -p mypassword    # Check status (auto password via sshpass)
# ============================================

# --- CONFIG ---
SSH_USER="your_username"
SSH_PORT=22

# --- TARGET LIST ---
# Format: "IP:CONTAINER_NAME"
# Add new lines as needed
TARGETS=(
    "1.1.1.1:cds-a"
    "2.2.2.2:cds-b"
    # "3.3.3.3:cds-c"
    # "4.4.4.4:cds-d"
)

# --- COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- PARSE ARGUMENTS ---
ACTION="$1"
SSH_PASS=""

if [[ "$2" == "-p" && -n "$3" ]]; then
    SSH_PASS="$3"
    if ! command -v sshpass &> /dev/null; then
        echo -e "${RED}[ERROR] sshpass is not installed.${NC}"
        echo "Install it: sudo apt install sshpass"
        exit 1
    fi
fi

# --- CHECK ACTION ---
if [[ -z "$ACTION" ]]; then
    echo "Usage: $0 {stop|start|status} [-p password]"
    echo ""
    echo "  stop      Stop all containers"
    echo "  start     Start all containers"
    echo "  status    Check status of all containers"
    echo ""
    echo "Options:"
    echo "  -p password   Use sshpass for auto login (no interactive prompt)"
    echo "                If omitted, you will be prompted for password per VM"
    exit 1
fi

if [[ ! "$ACTION" =~ ^(stop|start|status)$ ]]; then
    echo -e "${RED}[ERROR] Unknown action: $ACTION${NC}"
    echo "Usage: $0 {stop|start|status} [-p password]"
    exit 1
fi

# --- SSH COMMAND BUILDER ---
run_ssh() {
    local ip="$1"
    local cmd="$2"

    if [[ -n "$SSH_PASS" ]]; then
        sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
            -p "$SSH_PORT" "$SSH_USER@$ip" "$cmd" 2>&1
    else
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
            -p "$SSH_PORT" "$SSH_USER@$ip" "$cmd" 2>&1
    fi
}

# --- MAIN ---
MODE="interactive"
[[ -n "$SSH_PASS" ]] && MODE="sshpass (auto)"

echo "=========================================="
echo "   Docker Container Remote Manager"
echo "   Action : ${ACTION^^}"
echo "   Mode   : $MODE"
echo "=========================================="
echo ""

for target in "${TARGETS[@]}"; do
    IFS=':' read -r ip container <<< "$target"

    if [[ "$ACTION" == "status" ]]; then
        echo -e "${YELLOW}[INFO] Checking $ip -> '$container'...${NC}"
        result=$(run_ssh "$ip" "docker ps -a --filter name=^${container}$ --format '{{.Names}} | Status: {{.Status}}'")

        if [ $? -eq 0 ] && [ -n "$result" ]; then
            echo -e "  ${GREEN}$result${NC}"
        else
            echo -e "  ${RED}Container '$container' not found or connection failed.${NC}"
        fi
    else
        echo -e "${YELLOW}[INFO] $ip -> docker $ACTION '$container'...${NC}"
        result=$(run_ssh "$ip" "docker $ACTION $container")

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[OK] $ip -> '$container' ${ACTION} successful.${NC}"
        else
            echo -e "${RED}[FAIL] $ip -> '$container' ${ACTION} failed. Error: $result${NC}"
        fi
    fi
done

echo ""
echo "------------------------------------------"
echo -e "${GREEN}Done!${NC}"