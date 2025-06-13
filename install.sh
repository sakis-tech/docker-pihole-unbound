cat install.sh
#!/usr/bin/env bash
set -euo pipefail

# Farben
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

REPO_URL="https://github.com/sakis-tech/docker-pihole-unbound.git"
REPO_DIR="docker-pihole-unbound"

# Header anzeigen
show_header() {
  clear
  echo -e "${YELLOW}=============================================="
  echo -e "     Pi-hole + Unbound Auto‑Installer"
  echo -e "==============================================${NC}"
  echo "This script will automatically:"
  echo "- Install Docker & Docker Compose"
  echo "- Install Git & Curl"
  echo "- Clone the project"
  echo "- Create .env and docker-compose.yaml"
  echo "- Launch Pi-hole + Unbound using Docker"
  echo
}

pause_for_user() {
  read -rp "→ Press [Enter] to begin..."
}

check_requirements() {
  echo -e "\n${YELLOW}▶ Checking Docker & Docker Compose...${NC}"
  DOCKER_OK=false
  DOCKER_COMPOSE_OK=false

  if command -v docker &>/dev/null && docker --version &>/dev/null; then
    echo "Docker version: $(docker --version)"
    DOCKER_OK=true
  else
    echo "Docker not found"
  fi

  if command -v docker-compose &>/dev/null && docker-compose --version &>/dev/null; then
    echo "Docker Compose version: $(docker-compose --version)"
    DOCKER_COMPOSE_OK=true
  else
    echo "Docker Compose not found"
  fi

  if [ "$DOCKER_OK" = false ] || [ "$DOCKER_COMPOSE_OK" = false ]; then
    read -rp "→ Install missing tools? [y/N]: " INSTALL_TOOLS
    if [[ "$INSTALL_TOOLS" =~ ^[Yy]$ ]]; then
      install_missing_tools
    else
      echo -e "${RED}Aborting – required tools missing.${NC}"
      exit 1
    fi
  else
    echo -e "${GREEN}Docker & Compose are installed.${NC}"
  fi
}

detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  else
    echo "unknown"
  fi
}

install_missing_tools() {
  echo -e "${YELLOW}▶ Installing Git & Curl...${NC}"
  OS_ID=$(detect_os)

  case "$OS_ID" in
    debian | ubuntu | raspbian)
      sudo apt update
      sudo apt install -y curl git
      ;;
    fedora)
      sudo dnf install -y curl git
      ;;
    alpine)
      sudo apk add curl git
      ;;
    *)
      echo -e "${RED}Unsupported OS. Please install curl/git manually.${NC}"
      exit 1
      ;;
  esac

  echo -e "${YELLOW}▶ Installing Docker...${NC}"
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh

  echo -e "${YELLOW}▶ Installing Docker Compose...${NC}"
  sudo apt install -y docker-compose || true
}

check_docker_group() {
  echo -e "\n${YELLOW}▶ Checking docker group for ${USER}...${NC}"
  if groups "$USER" | grep -q '\bdocker\b'; then
    echo -e "${GREEN}${USER} is already in the docker group.${NC}"
  else
    read -rp "→ Add ${USER} to docker group? [y/N]: " ADD_GROUP
    if [[ "$ADD_GROUP" =~ ^[Yy]$ ]]; then
      sudo usermod -aG docker "$USER"
      echo -e "${YELLOW}Please log out and back in to apply group changes.${NC}"
    fi
  fi
}

clone_repo() {
  echo -e "\n${YELLOW}▶ Cloning repository…${NC}"
  if [ -d "$REPO_DIR" ]; then
    echo -e "${GREEN}$REPO_DIR already exists – skipping.${NC}"
  else
    git clone "$REPO_URL"
    cd "$REPO_DIR"
  fi
}

dir_setup() {
  echo -e "${YELLOW}▶ Creating configuration directories…${NC}"
  mkdir -p config/pihole config/unbound
}

prompt_env() {
  echo -e "\n${YELLOW}▶ Creating .env file…${NC}"
  read -rp "Use example config? (Europe/Berlin, web pw 'admin', DHCP 192.168.1.100–200, gateway 192.168.1.1, eth0)? [Y/n]: " USE_EXAMPLE
  if [[ "$USE_EXAMPLE" =~ ^[Nn]$ ]]; then
    read -rp "Timezone (e.g. Europe/Berlin): " TZ
    read -rp "Web admin password: " WEBPASSWORD
    read -rp "DHCP Range Start (e.g. 192.168.1.100): " DHCP_START
    read -rp "DHCP Range End (e.g. 192.168.1.200): " DHCP_END
    read -rp "DHCP Gateway/Router IP (e.g. 192.168.1.1): " DHCP_ROUTER
    read -rp "DHCP Interface (e.g. eth0): " DHCP_IF
    read -rp "Pi-hole Web UI Port (e.g. 80): " PIHOLE_WEBPORT
    PIHOLE_WEBPORT=${PIHOLE_WEBPORT:-80}
  else
    TZ="Europe/Berlin"
    WEBPASSWORD="admin"
    DHCP_START="192.168.1.100"
    DHCP_END="192.168.1.200"
    DHCP_ROUTER="192.168.1.1"
    DHCP_IF="eth0"
    PIHOLE_WEBPORT="80"
  fi

  cat > .env <<EOF
TZ=$TZ
WEBPASSWORD=$WEBPASSWORD
PIHOLE_DHCP_START=$DHCP_START
PIHOLE_DHCP_END=$DHCP_END
PIHOLE_DHCP_ROUTER=$DHCP_ROUTER
PIHOLE_DHCP_INTERFACE=$DHCP_IF
PIHOLE_WEBPORT=$PIHOLE_WEBPORT
HOSTNAME=pihole
DOMAIN_NAME=local
EOF
}

generate_compose() {
  echo -e "\n${YELLOW}▶ Creating docker-compose.yaml…${NC}"
  cat > docker-compose.yaml <<'EOF'
version: "3.8"
services:
  pihole-unbound:
    container_name: pihole-unbound
    image: mpgirro/pihole-unbound:latest
    network_mode: host
    hostname: ${HOSTNAME}
    domainname: ${DOMAIN_NAME}
    cap_add:
      - NET_ADMIN
      - SYS_TIME
      - SYS_NICE
    environment:
      - TZ=${TZ}
      - FTLCONF_webserver_api_password=${WEBPASSWORD}
      - FTLCONF_webserver_interface_theme=default-light
      - FTLCONF_dns_upstreams=127.0.0.1#5335
      - FTLCONF_dns_listeningMode=all
      - FTLCONF_webserver_port=${PIHOLE_WEBPORT}
      - DHCP_START=${PIHOLE_DHCP_START}
      - DHCP_END=${PIHOLE_DHCP_END}
      - DHCP_ROUTER=${PIHOLE_DHCP_ROUTER}
      - DHCP_INTERFACE=${PIHOLE_DHCP_INTERFACE}
    volumes:
      - ./config/pihole:/etc/pihole:rw
      - ./config/pihole:/etc/dnsmasq.d:rw
    restart: unless-stopped

EOF
}

finish_message() {
  echo -e "${GREEN}▶ Starting Docker containers...${NC}"
  docker-compose up -d

  HOST_IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
  if [ -z "$HOST_IP" ]; then
    HOST_IP="localhost"
  fi

  echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "🎉 Pi-hole Web Interface is ready!\n"
  echo -e "→ Open in browser: http://${HOST_IP}:${PIHOLE_WEBPORT}\n"
  echo -e "📍 Login Password: ${WEBPASSWORD}\n"
  echo -e "🛠️ Configuration Info:"
  echo -e "   - Web UI: Pi-hole settings and DHCP"
  echo -e "   - Unbound: ./config/unbound/unbound.conf\n"
  echo -e "💡 Tip: Restart containers with:"
  echo -e "   docker-compose restart"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n${NC}"
}

main() {
  show_header
  pause_for_user
  check_requirements
  check_docker_group
  clone_repo
  dir_setup
  prompt_env
  generate_compose
  finish_message
}

main
