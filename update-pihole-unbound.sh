#!/usr/bin/env bash
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Repository directory name (should match install script)
REPO_DIR="docker-pihole-unbound"

# Load .env if it exists in the project directory
# If not in repo folder, switch to it
if [[ ! -f "docker-compose.yaml" && -d "$REPO_DIR" ]]; then
  cd "$REPO_DIR"
elif [[ ! -f "docker-compose.yaml" ]]; then
  echo -e "${RED}❌ docker-compose.yaml not found. Make sure you're in the project directory or that '${REPO_DIR}' exists.${NC}"
  exit 1
fi

ENV_FILE=".env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo -e "${RED}❌ .env file not found. Make sure you're in the project directory.${NC}"
  exit 1
fi
# shellcheck disable=SC1091
source <(grep -E '^[A-Z0-9_]+=' "$ENV_FILE")

print_header() {
  clear
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${BLUE}🔄 Pi-hole + Unbound Update Script                            ${NC}"
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${GREEN}This script will automatically:
${NC}- ${YELLOW}Pull the latest Docker images
${NC}- ${YELLOW}Restart the containers using updated images
${NC}- ${YELLOW}Optionally show container logs${NC}"
  echo -e "${GREEN}Press [Enter] to continue...${NC}"
  read -r _
}

check_compose() {
  if command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
  elif docker compose version &>/dev/null; then
    COMPOSE_CMD="docker compose"
  else
    echo -e "${RED}❌ Docker Compose is not installed. Please run the install script first.${NC}"
    exit 1
  fi
}

update_containers() {
  echo -e "${YELLOW}🔄 Pulling latest images...${NC}"
  $COMPOSE_CMD pull
  echo -e "${YELLOW}🚀 Restarting containers...${NC}"
  $COMPOSE_CMD up -d
}

show_status() {
  echo -e "\n${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${BLUE}🎉 Update Completed!                                          ${NC}"
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${GREEN}• Pi-hole IP: ${NC}${YELLOW}${PIHOLE_IP}${NC}"
  echo -e "${GREEN}• Web Port: ${NC}${YELLOW}${PIHOLE_WEBPORT}${NC}"
  echo -e "${GREEN}• Domain: ${NC}${YELLOW}${DOMAIN_NAME}${NC}"
  echo -e "${GREEN}• Theme: ${NC}${YELLOW}${WEBTHEME}${NC}"
  echo -e "${GREEN}• Hostname: ${NC}${YELLOW}${HOSTNAME}${NC}"
  echo -e "${GREEN}• Timezone: ${NC}${YELLOW}${TZ}${NC}"
  echo -e "\n${GREEN}Do you want to see the logs? (y/N)${NC}"
  read -r SHOW_LOGS
  if [[ "$SHOW_LOGS" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
    echo -e "${BLUE}🧾 Latest Logs:                                              ${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
    $COMPOSE_CMD logs --tail 20
  fi
}

main() {
  print_header
  check_compose
  update_containers
  show_status
}

main
