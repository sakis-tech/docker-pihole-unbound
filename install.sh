#!/usr/bin/env bash
set -euo pipefail

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
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${BLUE}  🚀 Pi-hole + Unbound Auto‑Installer                         ${NC}"
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${GREEN}This script will automatically:\n${NC}- ${YELLOW}Install Docker & Docker Compose\n${NC}- ${YELLOW}Install Git & Curl\n${NC}- ${YELLOW}Clone the project\n${NC}- ${YELLOW}Create .env and docker-compose.yaml\n${NC}- ${YELLOW}Setup Docker macvlan network\n${NC}- ${YELLOW}Launch Pi-hole + Unbound using Docker${NC}"
  echo -e "${GREEN}Press [Enter] to begin...${NC}"
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

download_unbound_conf() {
  echo -e "${YELLOW}⬇️  Downloading unbound-pihole.conf…${NC}"
  curl -fsSL https://raw.githubusercontent.com/mpgirro/docker-pihole-unbound/main/docker/unbound-pihole.conf -o ./config/unbound/unbound-pihole.conf
  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ unbound-pihole.conf downloaded successfully.${NC}"
  else
    echo -e "${RED}❌ Failed to download unbound-pihole.conf.${NC}"
    exit 1
  fi
}


prompt_env() {
  echo -e "\n${BLUE}─────────────────────────────────────────────────────────────"
  echo -e "📄 .env Configuration"
  echo -e "─────────────────────────────────────────────────────────────${NC}"
  echo -e "${YELLOW}Example Configuration:\n${NC}  • ${GREEN}Timezone: Europe/Berlin\n${NC}  • ${GREEN}Web Password: admin\n${NC}  • ${GREEN}Web Port: 80\n${NC}  • ${GREEN}Domain: local\n${NC}  • ${GREEN}Web Theme: default-dark\n${NC}  • ${GREEN}Hostname: pihole\n${NC}  • ${GREEN}Pihole static IP (e.g. 192.168.10.50)${NC}"

  echo -e "\n${YELLOW}❓ Use example config? [Y/n]: ${NC}\c"
  read -r USE_EXAMPLE

  if [[ "$USE_EXAMPLE" =~ ^[Nn]$ ]]; then
    echo -ne "${GREEN}Timezone (e.g. Europe/Berlin): ${NC}"
	read -r TZ
	echo -ne "${GREEN}Web admin password: ${NC}"
	read -r WEBPASSWORD
	echo -ne "${GREEN}Web port: ${NC}"
	read -r PIHOLE_WEBPORT
	echo -ne "${GREEN}Domain name (e.g. local): ${NC}"
	read -r DOMAIN_NAME
	echo -ne "${GREEN}Web theme (default-dark or default-light): ${NC}"
	read -r WEBTHEME
	echo -ne "${GREEN}Hostname (e.g. pihole): ${NC}"
	read -r HOSTNAME
	echo -ne "${GREEN}Pihole static IP (e.g. 192.168.10.50): ${NC}"
	read -r PIHOLE_IP
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
PIHOLE_IP=$PIHOLE_IP
EOF
}

prompt_macvlan() {
  echo -e "\n${BLUE}─────────────────────────────────────────────────────────────"
  echo -e "🔌 Docker Macvlan Configuration"
  echo -e "─────────────────────────────────────────────────────────────${NC}"
  echo -e "${GREEN}Available network interfaces:${NC}"
  ip -o link show | awk -F': ' '{print "  • "$2}' | grep -vE "lo|docker"

  echo -ne "\n${YELLOW}❓ Select parent interface for macvlan (e.g. eth0): ${NC}"
  read -r MACVLAN_PARENT

  echo -ne "${YELLOW}❓ Subnet (e.g. 192.168.10.0/24): ${NC}"
  read -r MACVLAN_SUBNET

  echo -ne "${YELLOW}❓ Gateway (e.g. 192.168.10.1): ${NC}"
  read -r MACVLAN_GATEWAY

  echo -ne "${YELLOW}❓ Pi-hole IP (e.g. 192.168.10.50): ${NC}"
  read -r PIHOLE_IP
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
  echo -e "${YELLOW}📝 Generating docker-compose.yaml…${NC}"
  cat > docker-compose.yaml <<EOF
services:
  pihole-unbound:
    container_name: pihole-unbound
    image: mpgirro/pihole-unbound:latest
    networks:
      pihole_macvlan:
        ipv4_address: \${PIHOLE_IP}
    hostname: \${HOSTNAME}
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
      - FTLCONF_dns_domain=\${DOMAIN_NAME}
      - FTLCONF_webserver_port=\${PIHOLE_WEBPORT}
    volumes:
      - ./config/pihole:/etc/pihole:rw
      - ./config/pihole:/etc/dnsmasq.d:rw
      - ./config/unbound:/etc/unbound/unbound.conf.d:rw
      - ./logs/unbound:/var/log/unbound:rw
      - ./config/unbound/root.hints:/etc/unbound/root.hints:ro
      - ./config/unbound/root.key:/etc/unbound/root.key:ro
    restart: unless-stopped

networks:
  pihole_macvlan:
    external: true
EOF
}

start_containers() {
  echo -e "${YELLOW}🚀 Starting Docker containers…${NC}"
  docker-compose up -d
}

print_success() {
  echo -e "\n${BLUE}─────────────────────────────────────────────────────────────"
  echo -e "🎉 Pi-hole is now running!"
  echo -e "─────────────────────────────────────────────────────────────${NC}"
  echo -e "${GREEN}\n➡️  Access:${NC} ${YELLOW}http://${PIHOLE_IP}:${PIHOLE_WEBPORT}${NC}"
  echo -e "${GREEN}🔑 Login Password:${NC} ${YELLOW}Set in .env${NC}"
  echo -e "${GREEN}📁 Unbound config:${NC} ${YELLOW}./config/unbound/unbound-pihole.conf${NC}"
  echo -e "${GREEN}🔁 Restart with:${NC} ${YELLOW}docker-compose restart${NC}\n"
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
  download_unbound_conf
  prompt_env
  prompt_macvlan
  create_macvlan_network
  generate_compose
  start_containers
  print_success
}

main "$@"
