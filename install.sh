#!/usr/bin/env bash
set -euo pipefail

# Farben für Ausgabe
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# GitHub Repo
REPO_URL="https://github.com/mpgirro/docker-pihole-unbound.git"
REPO_DIR="docker-pihole-unbound"

print_header() {
  clear
  echo -e "${GREEN}==============================================${NC}"
  echo -e "${GREEN}     Pi-hole + Unbound Auto‑Installer         ${NC}"
  echo -e "${GREEN}==============================================${NC}"
  echo -e "This script will automatically:"
  echo -e "- Install Docker & Docker Compose"
  echo -e "- Install Git & Curl"
  echo -e "- Clone the project"
  echo -e "- Create .env and docker-compose.yaml"
  echo -e "- Setup Docker macvlan network"
  echo -e "- Launch Pi-hole + Unbound using Docker"
  echo -e "\n→ Press [Enter] to begin..."
  read -r _
}

check_command() {
  command -v "$1" &>/dev/null
}

install_docker() {
  echo -e "${YELLOW}▶ Installing Docker…${NC}"
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  rm get-docker.sh
}

install_docker_compose() {
  echo -e "${YELLOW}▶ Installing Docker Compose…${NC}"
  # Compose v2 embedded in Docker >= 20.10, else fallback
  if docker compose version &>/dev/null; then
    echo "Docker Compose plugin is already installed."
    return
  fi
  # Für ältere Systeme hier Docker Compose v1 als fallback:
  sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docke                                                                                                                                                             r-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
}

install_git_curl() {
  echo -e "${YELLOW}▶ Installing Git and Curl…${NC}"
  if [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
    sudo apt-get update
    sudo apt-get install -y git curl
  elif [[ "$OS" == "centos" || "$OS" == "fedora" ]]; then
    sudo yum install -y git curl
  else
    echo -e "${RED}Unsupported OS for automatic Git/Curl install. Please install                                                                                                                                                              manually.${NC}"
    exit 1
  fi
}

detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
      debian|ubuntu) OS="debian" ;;
      centos|fedora) OS="centos" ;;
      *) OS="unknown" ;;
    esac
  else
    OS="unknown"
  fi
}

check_docker() {
  if check_command docker; then
    if docker version &>/dev/null; then
      echo -e "${GREEN}Docker version: $(docker version --format '{{.Server.Vers                                                                                                                                                             ion}}')${NC}"
      return 0
    fi
  fi
  echo -e "${RED}Docker not found.${NC}"
  return 1
}

check_docker_compose() {
  # Prüft docker-compose v1 oder v2 (docker compose)
  if check_command docker-compose; then
    echo -e "${GREEN}Docker Compose version: $(docker-compose version --short)${                                                                                                                                                             NC}"
    return 0
  elif docker compose version &>/dev/null; then
    echo -e "${GREEN}Docker Compose (plugin) version: $(docker compose version -                                                                                                                                                             -short)${NC}"
    return 0
  fi
  echo -e "${RED}Docker Compose not found.${NC}"
  return 1
}

check_docker_group() {
  local user=$1
  if id -nG "$user" | grep -qw docker; then
    echo -e "${GREEN}$user is already in docker group.${NC}"
    return 0
  else
    echo -e "${YELLOW}$user is NOT in docker group.${NC}"
    return 1
  fi
}

add_user_to_docker_group() {
  local user=$1
  echo -e "${YELLOW}▶ Adding $user to docker group…${NC}"
  sudo usermod -aG docker "$user"
  echo -e "${GREEN}User $user added to docker group. Please logout and login aga                                                                                                                                                             in for changes to take effect.${NC}"
}

clone_repo() {
  if [[ -d "$REPO_DIR" ]]; then
    echo -e "${YELLOW}Repository $REPO_DIR already exists — skipping clone.${NC}                                                                                                                                                             "
  else
    echo -e "${YELLOW}▶ Cloning repository from $REPO_URL …${NC}"
    git clone "$REPO_URL"
  fi
}

create_config_dirs() {
  echo -e "${YELLOW}▶ Creating configuration directories…${NC}"
  mkdir -p config/pihole config/unbound
}

prompt_env() {
  echo -e "\n${YELLOW}▶ Creating .env file…${NC}"
  read -rp "Use example config? (Europe/Berlin, web pw 'admin', DHCP 192.168.1.1                                                                                                                                                             00–200, gateway 192.168.1.1, eth0)? [Y/n]: " USE_EXAMPLE
  if [[ "$USE_EXAMPLE" =~ ^[Nn]$ ]]; then
    read -rp "Timezone (e.g. Europe/Berlin): " TZ
    read -rp "Web admin password: " WEBPASSWORD
    read -rp "Pi-hole Web Port (e.g. 80): " PIHOLE_WEBPORT
    read -rp "Domain Name (e.g. local): " DOMAIN_NAME
  else
    TZ="Europe/Berlin"
    WEBPASSWORD="admin"
    PIHOLE_WEBPORT="80"
  fi

  cat > .env <<EOF
TZ=$TZ
WEBPASSWORD=$WEBPASSWORD
PIHOLE_WEBPORT=$PIHOLE_WEBPORT
HOSTNAME=pihole
DOMAIN_NAME=local
EOF
}

prompt_macvlan() {
  echo -e "\n${YELLOW}▶ Configure Docker macvlan network…${NC}"
  read -rp "Parent interface for macvlan (e.g. eth0): " MACVLAN_PARENT
  read -rp "Subnet for macvlan (e.g. 192.168.10.0/24): " MACVLAN_SUBNET
  read -rp "Gateway for macvlan (e.g. 192.168.10.1): " MACVLAN_GATEWAY
  read -rp "IP for Pi-hole container (within subnet, e.g. 192.168.10.50): " PIHO                                                                                                                                                             LE_IP
}

create_macvlan_network() {
  echo -e "\n${YELLOW}▶ Creating Docker macvlan network if not exists…${NC}"
  if ! docker network ls --format '{{.Name}}' | grep -q "^pihole_macvlan$"; then
    docker network create -d macvlan \
      --subnet=${MACVLAN_SUBNET} \
      --gateway=${MACVLAN_GATEWAY} \
      -o parent=${MACVLAN_PARENT} \
      pihole_macvlan
    echo -e "${GREEN}macvlan network 'pihole_macvlan' created.${NC}"
  else
    echo -e "${YELLOW}macvlan network 'pihole_macvlan' already exists — skipping                                                                                                                                                             .${NC}"
  fi
}

generate_compose() {
  echo -e "\n${YELLOW}▶ Creating docker-compose.yaml…${NC}"
  cat > docker-compose.yaml <<EOF
version: "3.8"
services:
  pihole-unbound:
    container_name: pihole-unbound
    image: mpgirro/pihole-unbound:latest
    networks:
      pihole_macvlan:
        ipv4_address: ${PIHOLE_IP}
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
    volumes:
      - ./config/pihole:/etc/pihole:rw
      - ./config/pihole:/etc/dnsmasq.d:rw
    restart: unless-stopped

networks:
  pihole_macvlan:
    external: true
EOF
}

start_containers() {
  echo -e "\n${YELLOW}▶ Starting Docker containers…${NC}"
  docker-compose up -d
}

print_success() {
  echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}                                                                                                                                                             "
  echo -e "${GREEN}🎉 Pi-hole Web Interface is ready!${NC}"
  echo -e "\n→ Open in browser: http://${PIHOLE_IP}:${PIHOLE_WEBPORT}"
  echo -e "\n📍 Login Password: (set in .env)"
  echo -e "\n🛠️ Configuration Info:"
  echo -e "   - Web UI: Pi-hole settings and DHCP"
  echo -e "   - Unbound config: ./config/unbound/unbound.conf"
  echo -e "\n💡 Tip: Restart containers with:"
  echo -e "   docker-compose restart"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n                                                                                                                                                             "
}

main() {
  print_header

  detect_os

  if ! check_command docker || ! check_docker; then
    install_docker
  fi

  if ! check_command docker-compose || ! check_docker_compose; then
    install_docker_compose
  fi

  if ! check_command git; then
    install_git_curl
  fi

  if ! check_command curl; then
    install_git_curl
  fi

  CURRENT_USER=$(whoami)
  if ! check_docker_group "$CURRENT_USER"; then
    add_user_to_docker_group "$CURRENT_USER"
    echo -e "${YELLOW}Please logout and login again, then rerun the script.${NC}                                                                                                                                                             "
    exit 0
  fi

  clone_repo
  cd "$REPO_DIR"

  create_config_dirs

  prompt_env
  prompt_macvlan

  create_macvlan_network

  generate_compose

  start_containers

  print_success
}

main "$@"
