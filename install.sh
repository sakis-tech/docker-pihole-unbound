#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# 🌐 Pi-hole + Unbound Auto‑Installer
# ─────────────────────────────────────────────────────────────

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

REPO_URL="https://github.com/mpgirro/docker-pihole-unbound.git"
REPO_DIR="docker-pihole-unbound"

print_header() {
  clear
  echo -e "${GREEN}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${GREEN}  🚀 Pi-hole + Unbound Auto‑Installer                         ${NC}"
  echo -e "${GREEN}─────────────────────────────────────────────────────────────${NC}"
  echo -e "This script will automatically:\n- Install Docker & Docker Compose\n- Install Git & Curl\n- Clone the project\n- Create .env and docker-compose.yaml\n- Setup Docker macvlan network\n- Launch Pi-hole + Unbound using Docker"
  echo -e "\n➡️  Press [Enter] to begin..."
  read -r _
}

check_command() { command -v "$1" &>/dev/null; }

install_docker() {
  echo -e "${YELLOW}🔧 Installing Docker…${NC}"
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  rm get-docker.sh
}

install_docker_compose() {
  echo -e "${YELLOW}🔧 Installing Docker Compose…${NC}"
  if docker compose version &>/dev/null; then
    echo -e "${GREEN}✅ Docker Compose plugin is already installed.${NC}"
    return
  fi
  sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
}

install_git_curl() {
  echo -e "${YELLOW}🔧 Installing Git and Curl…${NC}"
  if [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
    sudo apt-get update
    sudo apt-get install -y git curl
  elif [[ "$OS" == "centos" || "$OS" == "fedora" ]]; then
    sudo yum install -y git curl
  else
    echo -e "${RED}❌ Unsupported OS for automatic Git/Curl install.${NC}"
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
  if check_command docker && docker version &>/dev/null; then
    echo -e "${GREEN}✅ Docker version: $(docker version --format '{{.Server.Version}}')${NC}"
    return 0
  fi
  echo -e "${RED}❌ Docker not found.${NC}"
  return 1
}

check_docker_compose() {
  if check_command docker-compose; then
    echo -e "${GREEN}✅ Docker Compose version: $(docker-compose version --short)${NC}"
    return 0
  elif docker compose version &>/dev/null; then
    echo -e "${GREEN}✅ Docker Compose (plugin) version: $(docker compose version --short)${NC}"
    return 0
  fi
  echo -e "${RED}❌ Docker Compose not found.${NC}"
  return 1
}

check_docker_group() {
  local user=$1
  if id -nG "$user" | grep -qw docker; then
    echo -e "${GREEN}✅ $user is already in docker group.${NC}"
    return 0
  else
    echo -e "${YELLOW}⚠️ $user is NOT in docker group.${NC}"
    return 1
  fi
}

add_user_to_docker_group() {
  local user=$1
  echo -e "${YELLOW}➕ Adding $user to docker group…${NC}"
  sudo usermod -aG docker "$user"
  echo -e "${GREEN}✅ User $user added to docker group. Please logout/login again.${NC}"
}

clone_repo() {
  if [[ -d "$REPO_DIR" ]]; then
    echo -e "${YELLOW}📁 Repository already exists — skipping clone.${NC}"
  else
    echo -e "${YELLOW}📥 Cloning repository…${NC}"
    git clone "$REPO_URL"
  fi
}

create_config_dirs() {
  echo -e "${YELLOW}📁 Creating configuration directories…${NC}"
  mkdir -p config/pihole config/unbound
}

prompt_env() {
  echo -e "\n${BLUE}─────────────────────────────────────────────────────────────"
  echo -e "📄 .env Configuration"
  echo -e "─────────────────────────────────────────────────────────────${NC}"
  echo -e "\nExample Configuration:\n  • Timezone: Europe/Berlin\n  • Web Password: admin\n  • Web Port: 80\n  • Domain: local\n  • Web Theme: default-dark\n  • Hostname: pihole"

  read -rp "\n❓ Use example config? [Y/n]: " USE_EXAMPLE
  if [[ "$USE_EXAMPLE" =~ ^[Nn]$ ]]; then
    read -rp "Timezone (e.g. Europe/Berlin): " TZ
    read -rp "Web admin password: " WEBPASSWORD
    read -rp "Web port: " PIHOLE_WEBPORT
    read -rp "Domain name (e.g. local): " DOMAIN_NAME
    read -rp "Web theme (default-dark or default-light): " WEBTHEME
    read -rp "Hostname (e.g. pihole): " HOSTNAME
  else
    TZ="Europe/Berlin"
    WEBPASSWORD="admin"
    PIHOLE_WEBPORT="80"
    DOMAIN_NAME="local"
    WEBTHEME="default-dark"
    HOSTNAME="pihole"
  fi

  cat > .env <<EOF
TZ=$TZ
WEBPASSWORD=$WEBPASSWORD
PIHOLE_WEBPORT=$PIHOLE_WEBPORT
DOMAIN_NAME=$DOMAIN_NAME
WEBTHEME=$WEBTHEME
HOSTNAME=$HOSTNAME
EOF
}

prompt_macvlan() {
  echo -e "\n${BLUE}─────────────────────────────────────────────────────────────"
  echo -e "🔌 Docker Macvlan Configuration"
  echo -e "─────────────────────────────────────────────────────────────${NC}"
  echo -e "Available network interfaces:"
  ip -o link show | awk -F': ' '{print "  • "$2}' | grep -vE "lo|docker"
  read -rp "\n❓ Select parent interface for macvlan (e.g. eth0): " MACVLAN_PARENT
  read -rp "Subnet (e.g. 192.168.10.0/24): " MACVLAN_SUBNET
  read -rp "Gateway (e.g. 192.168.10.1): " MACVLAN_GATEWAY
  read -rp "Pi-hole IP (e.g. 192.168.10.50): " PIHOLE_IP
}

create_macvlan_network() {
  echo -e "\n${YELLOW}⚙️  Creating macvlan network if it does not exist…${NC}"
  if ! docker network ls --format '{{.Name}}' | grep -q "^pihole_macvlan$"; then
    docker network create -d macvlan \
      --subnet=${MACVLAN_SUBNET} \
      --gateway=${MACVLAN_GATEWAY} \
      -o parent=${MACVLAN_PARENT} \
      pihole_macvlan
    echo -e "${GREEN}✅ macvlan network 'pihole_macvlan' created.${NC}"
  else
    echo -e "${YELLOW}⚠️  macvlan network already exists — skipping.${NC}"
  fi
}

generate_compose() {
  echo -e "\n${YELLOW}📝 Generating docker-compose.yaml…${NC}"
  cat > docker-compose.yaml <<EOF
version: "3.8"
services:
  pihole-unbound:
    container_name: pihole-unbound
    image: mpgirro/pihole-unbound:latest
    networks:
      pihole_macvlan:
        ipv4_address: \${PIHOLE_IP}
    hostname: \${HOSTNAME}
    domainname: \${DOMAIN_NAME}
    cap_add:
      - NET_ADMIN
      - SYS_TIME
      - SYS_NICE
    environment:
      - TZ=\${TZ}
      - FTLCONF_webserver_api_password=\${WEBPASSWORD}
      - FTLCONF_webserver_interface_theme=\${WEBTHEME}
      - FTLCONF_dns_upstreams=127.0.0.1#5335
      - FTLCONF_dns_listeningMode=all
      - FTLCONF_webserver_port=\${PIHOLE_WEBPORT}
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
  echo -e "\n${YELLOW}🚀 Starting Docker containers…${NC}"
  docker-compose up -d
}

print_success() {
  echo -e "\n${GREEN}🎉 Pi-hole is now running!${NC}"
  echo -e "\n➡️  Access: http://\${PIHOLE_IP}:\${PIHOLE_WEBPORT}"
  echo -e "🔑 Login Password: Set in .env"
  echo -e "📁 Unbound config: ./config/unbound/unbound.conf"
  echo -e "🔁 Restart with: docker-compose restart"
}

main() {
  print_header
  detect_os
  check_docker || install_docker
  check_docker_compose || install_docker_compose
  check_command git || install_git_curl
  check_command curl || install_git_curl

  CURRENT_USER=$(whoami)
  check_docker_group "$CURRENT_USER" || {
    add_user_to_docker_group "$CURRENT_USER"
    echo -e "${YELLOW}Please logout and login again, then rerun the script.${NC}"
    exit 0
  }

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
