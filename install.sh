#!/usr/bin/env bash
set -euo pipefail

# Colors and Icons
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[1;36m'
NC='\033[0m'

CHECK="\xE2\x9C\x85"     # ✅
CROSS="\xE2\x9D\x8C"     # ❌
QUESTION="\xE2\x9D\x93"  # ❓
="\xE2\x9E\xA1"     # ➡️
INFO="\xF0\x9F\x93\x84"   # 📄
GEAR="\xF0\x9F\x94\xA7"   # 🔧
DOWNLOAD="\xF0\x9F\x93\xA6" # 📦

REPO_URL="https://github.com/mpgirro/docker-pihole-unbound.git"
REPO_DIR="docker-pihole-unbound"

print_header() {
  clear
  echo -e "${GREEN}==============================================${NC}"
  echo -e "${GREEN}     Pi-hole + Unbound Auto‑Installer         ${NC}"
  echo -e "${GREEN}==============================================${NC}"
  echo -e "${INFO} This script will automatically:"
  echo -e "  - Install Docker & Docker Compose"
  echo -e "  - Install Git & Curl"
  echo -e "  - Clone the project"
  echo -e "  - Create .env and docker-compose.yaml"
  echo -e "  - Setup Docker macvlan network"
  echo -e "  - Launch Pi-hole + Unbound using Docker"
  echo -e "\n${QUESTION}${} Press [Enter] to begin..."
  read -r _
}

print_section() {
  echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  $1"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

check_command() {
  command -v "$1" &>/dev/null
}

install_docker() {
  print_section "${DOWNLOAD} Installing Docker"
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  rm get-docker.sh
}

install_docker_compose() {
  print_section "${DOWNLOAD} Installing Docker Compose"
  if docker compose version &>/dev/null; then
    echo -e "${CHECK} Docker Compose plugin is already installed."
    return
  fi
  sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
}

install_git_curl() {
  print_section "${DOWNLOAD} Installing Git and Curl"
  if [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
    sudo apt-get update
    sudo apt-get install -y git curl
  elif [[ "$OS" == "centos" || "$OS" == "fedora" ]]; then
    sudo yum install -y git curl
  else
    echo -e "${RED}${CROSS} Unsupported OS for automatic Git/Curl install.${NC}"
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
    echo -e "${CHECK} Docker version: $(docker version --format '{{.Server.Version}}')"
    return 0
  fi
  echo -e "${RED}${CROSS} Docker not found.${NC}"
  return 1
}

check_docker_compose() {
  if check_command docker-compose; then
    echo -e "${CHECK} Docker Compose version: $(docker-compose version --short)"
    return 0
  elif docker compose version &>/dev/null; then
    echo -e "${CHECK} Docker Compose plugin version: $(docker compose version --short)"
    return 0
  fi
  echo -e "${RED}${CROSS} Docker Compose not found.${NC}"
  return 1
}

check_docker_group() {
  local user=$1
  if id -nG "$user" | grep -qw docker; then
    echo -e "${CHECK} $user is in the docker group."
    return 0
  else
    echo -e "${YELLOW}${CROSS} $user is NOT in the docker group.${NC}"
    return 1
  fi
}

add_user_to_docker_group() {
  local user=$1
  echo -e "${GEAR} Adding $user to docker group…"
  sudo usermod -aG docker "$user"
  echo -e "${CHECK} User $user added. Please logout and login again."
}

clone_repo() {
  print_section "${DOWNLOAD} Cloning Repository"
  if [[ -d "$REPO_DIR" ]]; then
    echo -e "${YELLOW}${INFO} Repository already exists — skipping clone.${NC}"
  else
    git clone "$REPO_URL"
  fi
}

create_config_dirs() {
  print_section "${GEAR} Creating Configuration Directories"
  mkdir -p config/pihole config/unbound
}

prompt_env() {
  print_section "${INFO} Generating .env Configuration"

  echo -e "${CYAN}Example Configuration:${NC}"
  echo -e "  🌍 Timezone:           Europe/Berlin"
  echo -e "  🔐 Web Admin Password: admin"
  echo -e "  🌐 Web Port:           80"
  echo -e "  🏷️  Domain Name:        local"
  echo -e "  💻 Hostname:           pihole"

  echo -e "\n${YELLOW}${QUESTION}${} Use this example configuration? [Y/n]${NC}"
  read -rp "> " USE_EXAMPLE

  if [[ "$USE_EXAMPLE" =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}${QUESTION}${} Timezone (e.g. Europe/Berlin):${NC}"; read -rp "> " TZ
    echo -e "${YELLOW}${QUESTION}${} Web admin password:${NC}"; read -rp "> " WEBPASSWORD
    echo -e "${YELLOW}${QUESTION}${} Pi-hole Web Port:${NC}"; read -rp "> " PIHOLE_WEBPORT
    echo -e "${YELLOW}${QUESTION}${} Domain Name:${NC}"; read -rp "> " DOMAIN_NAME
    HOSTNAME="pihole"
  else
    TZ="Europe/Berlin"
    WEBPASSWORD="admin"
    PIHOLE_WEBPORT="80"
    DOMAIN_NAME="local"
    HOSTNAME="pihole"
  fi

  cat > .env <<EOF
TZ=$TZ
WEBPASSWORD=$WEBPASSWORD
PIHOLE_WEBPORT=$PIHOLE_WEBPORT
HOSTNAME=$HOSTNAME
DOMAIN_NAME=$DOMAIN_NAME
EOF

  echo -e "${CHECK} .env file created."
}

prompt_macvlan() {
  print_section "${GEAR} Docker Macvlan Configuration"

  echo -e "${INFO} Available network interfaces:"
  ip -o link show | awk -F': ' '{print "  - "$2}'

  echo -e "\n${YELLOW}${QUESTION}${} Choose parent interface (e.g. eth0):${NC}"; read -rp "> " MACVLAN_PARENT
  echo -e "${YELLOW}${QUESTION}${} Subnet (e.g. 192.168.10.0/24):${NC}"; read -rp "> " MACVLAN_SUBNET
  echo -e "${YELLOW}${QUESTION}${} Gateway (e.g. 192.168.10.1):${NC}"; read -rp "> " MACVLAN_GATEWAY
  echo -e "${YELLOW}${QUESTION}${} Pi-hole IP (e.g. 192.168.10.50):${NC}"; read -rp "> " PIHOLE_IP
}

create_macvlan_network() {
  print_section "${GEAR} Creating Docker macvlan network"
  if ! docker network ls --format '{{.Name}}' | grep -q "^pihole_macvlan$"; then
    docker network create -d macvlan \
      --subnet=${MACVLAN_SUBNET} \
      --gateway=${MACVLAN_GATEWAY} \
      -o parent=${MACVLAN_PARENT} \
      pihole_macvlan
    echo -e "${CHECK} macvlan network 'pihole_macvlan' created."
  else
    echo -e "${INFO} macvlan network already exists — skipping."
  fi
}

generate_compose() {
  print_section "${INFO} Creating docker-compose.yaml"
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
  print_section "${GEAR} Starting Docker containers"
  docker-compose up -d
}

print_success() {
  echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CHECK} Pi-hole Web Interface is ready!"
  echo -e "Open in browser: http://${PIHOLE_IP}:${PIHOLE_WEBPORT}"
  echo -e "Login Password: (see .env)"
  echo -e "Config: ./config/unbound/unbound.conf"
  echo -e "Restart: docker-compose restart"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

main() {
  print_header
  detect_os

  if ! check_command docker || ! check_docker; then install_docker; fi
  if ! check_command docker-compose || ! check_docker_compose; then install_docker_compose; fi
  if ! check_command git || ! check_command curl; then install_git_curl; fi

  CURRENT_USER=$(whoami)
  if ! check_docker_group "$CURRENT_USER"; then
    add_user_to_docker_group "$CURRENT_USER"
    echo -e "${YELLOW}${INFO} Please logout and login again, then rerun the script.${NC}"
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
