#!/usr/bin/env bash
#######################################
# Pi-hole + Unbound Auto-Installer
# Version: 1.0
#
# Description: This script automates the installation of Pi-hole with Unbound DNS resolver
# running in a Docker container. It handles prerequisites installation, network configuration,
# and container setup.
#
# Author: Original by mpgirro, enhanced by Sakis
#######################################
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Icons/symbols
CHECK="\u2714"
CROSS="\u2718"
ARROW="\u25B6"
WARNING="\u26A0\uFE0F"
GEAR="\u2699"
SEARCH="\U1F50D"
RESTART="\U1F504"
DOWNLOAD="\U1F4E5"
WRITE="\U1F4DD"

# Constants
REPO_URL="https://github.com/mpgirro/docker-pihole-unbound.git"
REPO_DIR="docker-pihole-unbound"
PORTAINER_INSTALLED=false
HOST_IP=$(hostname -I | awk '{print $1}')
COMPOSE_FILE="docker-compose.yaml"

#######################################
# Prints script header and waits for user confirmation
# Globals:
#   BLUE, GREEN, YELLOW, NC
# Arguments:
#   None
#######################################
print_header() {
  clear
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${BLUE}  🚀 Pi-hole + Unbound Auto‑Installer                         ${NC}"
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${GREEN}This script will automatically:${NC}"
  echo -e "${YELLOW}  • ${GREEN}Install Docker & Docker Compose${NC}"
  echo -e "${YELLOW}  • ${GREEN}Install Git & Curl${NC}"
  echo -e "${YELLOW}  • ${GREEN}Clone the Project${NC}"
  echo -e "${YELLOW}  • ${GREEN}Create .env and ${COMPOSE_FILE}${NC}"
  echo -e "${YELLOW}  • ${GREEN}Setup Docker macvlan network${NC}"
  echo -e "${YELLOW}  • ${GREEN}Launch Pi-hole + Unbound using Docker${NC}"
  echo -e "${YELLOW}  • ${GREEN}Optional: Install Portainer (Docker GUI)${NC}"
  echo
  echo -e "${YELLOW}${WARNING} Do you wish to continue? [Y/n]${NC}"
  read -r CONTINUE

  if [[ "$CONTINUE" =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}Installation aborted.${NC}"
    exit 0
  fi
}

#######################################
# Check if command exists
# Arguments:
#   $1 - Command to check
# Returns:
#   0 if command exists, 1 otherwise
#######################################
check_command() { command -v "$1" &>/dev/null; }

#######################################
# Install Docker
# Globals:
#   GREEN, YELLOW, BLUE, ARROW, CHECK, NC
# Arguments:
#   None
#######################################
install_docker() {
  echo -e "${BLUE}${ARROW} Installing Docker...${NC}"
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  rm get-docker.sh
  echo -e "${GREEN}${CHECK} Docker successfully installed.${NC}"
}

#######################################
# Install Docker Compose
# Globals:
#   GREEN, YELLOW, BLUE, ARROW, CHECK, NC
# Arguments:
#   None
#######################################
install_docker_compose() {
  echo -e "${BLUE}${ARROW} Installing Docker Compose...${NC}"
  if docker compose version &>/dev/null; then
    echo -e "${GREEN}${CHECK} Docker Compose plugin is already installed.${NC}"
    return
  fi
  sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  echo -e "${GREEN}${CHECK} Docker Compose successfully installed.${NC}"
}

#######################################
# Install Git and Curl
# Globals:
#   GREEN, RED, YELLOW, BLUE, ARROW, CHECK, CROSS, NC, OS
# Arguments:
#   None
#######################################
install_git_curl() {
  echo -e "${BLUE}${ARROW} Installing Git and Curl...${NC}"
  if [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
    echo -e "${YELLOW}Running apt-get update...${NC}"
    sudo apt-get update
    echo -e "${GREEN}Installing git and curl packages...${NC}"
    sudo apt-get install -y git curl
  elif [[ "$OS" == "centos" || "$OS" == "fedora" ]]; then
    echo -e "${GREEN}Installing git and curl packages...${NC}"
    sudo yum install -y git curl
  else
    echo -e "${RED}${CROSS} Unsupported OS for automatic Git/Curl installation.${NC}"
    exit 1
  fi
  echo -e "${GREEN}${CHECK} Git and Curl successfully installed.${NC}"
}

#######################################
# Detect OS type for package management
# Globals:
#   GREEN, BLUE, ARROW, CHECK, NC
# Arguments:
#   None
# Sets:
#   OS
#######################################
detect_os() {
  echo -e "${BLUE}${ARROW} Detecting operating system...${NC}"
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
      debian|ubuntu)
        OS="debian"
        echo -e "${GREEN}${CHECK} Detected Debian/Ubuntu system.${NC}" ;;
      centos|fedora)
        OS="centos"
        echo -e "${GREEN}${CHECK} Detected CentOS/Fedora system.${NC}" ;;
      *)
        OS="unknown"
        echo -e "${YELLOW}${WARNING} Unknown OS type: $ID${NC}" ;;
    esac
  else
    OS="unknown"
    echo -e "${YELLOW}${WARNING} Could not detect operating system.${NC}"
  fi
}

#######################################
# Check if Portainer is installed
# Returns:
#   true if installed, false otherwise
#######################################
is_portainer_installed() {
  docker ps -a --format '{{.Names}}' | grep -qw portainer
}

#######################################
# Install Portainer if not already installed
# Globals:
#   GREEN, BLUE, YELLOW, ARROW, CHECK, NC, PORTAINER_INSTALLED
# Arguments:
#   None
#######################################
install_portainer() {
  if docker ps -a --format '{{.Names}}' | grep -qw portainer; then
    echo -e "${GREEN}${CHECK} Portainer container already exists - skipping installation.${NC}"
    PORTAINER_INSTALLED=true
    return
  fi

  echo -e "${BLUE}${ARROW} Installing Portainer...${NC}"
  sudo docker volume create portainer_data
  sudo docker run -d \
    --name portainer \
    -p 9000:9000 \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce
  PORTAINER_INSTALLED=true
  echo -e "${GREEN}${CHECK} Portainer was successfully installed.${NC}"
}


#######################################
# Prompt user if they want to install Portainer
# Globals:
#   GREEN, BLUE, YELLOW, CHECK, WARNING, NC, PORTAINER_INSTALLED
# Arguments:
#   None
#######################################
prompt_portainer() {
  echo -e "${BLUE}${ARROW} Checking for Portainer installation...${NC}"
  if is_portainer_installed; then
    echo -e "${GREEN}${CHECK} Portainer container already exists - skipping installation.${NC}"
    PORTAINER_INSTALLED=true
  else
    echo -e "${YELLOW}${WARNING} Portainer is not installed.${NC}"
    echo -ne "${YELLOW}Would you like to install Portainer? [Y/n]: ${NC}"
    read -r INSTALL_PORTAINER
    if [[ "$INSTALL_PORTAINER" =~ ^[Nn]$ ]]; then
      echo -e "${YELLOW}Portainer will not be installed.${NC}"
      PORTAINER_INSTALLED=false
    else
      install_portainer
    fi
  fi
}

#######################################
# Check if Docker is installed and working
# Globals:
#   GREEN, RED, BLUE, ARROW, CHECK, CROSS, NC
# Arguments:
#   None
# Returns:
#   0 if Docker is installed, 1 otherwise
#######################################
check_docker() {
  echo -e "${BLUE}${ARROW} Checking Docker installation...${NC}"
  if check_command docker && docker version &>/dev/null; then
    echo -e "${GREEN}${CHECK} Docker version: $(docker version --format '{{.Server.Version}}')${NC}"
    return 0
  fi
  echo -e "${RED}${CROSS} Docker not found.${NC}"
  return 1
}

#######################################
# Check if Docker Compose is installed and working
# Globals:
#   GREEN, RED, BLUE, ARROW, CHECK, CROSS, NC
# Arguments:
#   None
# Returns:
#   0 if Docker Compose is installed, 1 otherwise
#######################################
check_docker_compose() {
  echo -e "${BLUE}${ARROW} Checking Docker Compose installation...${NC}"
  if check_command docker-compose; then
    echo -e "${GREEN}${CHECK} Docker Compose version: $(docker-compose version --short)${NC}"
    return 0
  elif docker compose version &>/dev/null; then
    echo -e "${GREEN}${CHECK} Docker Compose (plugin) version: $(docker compose version --short)${NC}"
    return 0
  fi
  echo -e "${RED}${CROSS} Docker Compose not found.${NC}"
  return 1
}

#######################################
# Check if user is in docker group
# Globals:
#   GREEN, YELLOW, BLUE, ARROW, CHECK, WARNING, NC
# Arguments:
#   $1 - Username to check
# Returns:
#   0 if user is in docker group, 1 otherwise
#######################################
check_docker_group() {
  local user=$1
  echo -e "${BLUE}${ARROW} Checking if $user is in the docker group...${NC}"
  if id -nG "$user" | grep -qw docker; then
    echo -e "${GREEN}${CHECK} $user is already in docker group.${NC}"
    return 0
  else
    echo -e "${YELLOW}${WARNING} $user is NOT in docker group.${NC}"
    return 1
  fi
}

#######################################
# Add user to docker group
# Globals:
#   GREEN, YELLOW, BLUE, ARROW, CHECK, NC
# Arguments:
#   $1 - Username to add to docker group
#######################################
add_user_to_docker_group() {
  local user=$1
  echo -e "${BLUE}${ARROW} Adding $user to docker group...${NC}"
  sudo usermod -aG docker "$user"
  echo -e "${GREEN}${CHECK} User $user added to docker group. Please logout/login again.${NC}"
}

#######################################
# Clone the repository if it doesn't exist
# Globals:
#   GREEN, YELLOW, BLUE, ARROW, CHECK, DOWNLOAD, WARNING, NC, REPO_URL, REPO_DIR
# Arguments:
#   None
#######################################
clone_repo() {
  echo -e "${BLUE}${ARROW} Checking for repository...${NC}"
  if [[ -d "$REPO_DIR" ]]; then
    echo -e "${YELLOW}${WARNING} Repository already exists - skipping clone.${NC}"
  else
    echo -e "${GREEN}${DOWNLOAD} Cloning repository from ${REPO_URL}...${NC}"
    git clone "$REPO_URL"
    echo -e "${GREEN}${CHECK} Repository cloned successfully.${NC}"
  fi
}

#######################################
# Configure environment variables
# Globals:
#   BLUE, GREEN, YELLOW, ARROW, WRITE, WARNING, NC
#   TZ, WEBPASSWORD, PIHOLE_WEBPORT, DOMAIN_NAME, WEBTHEME, HOSTNAME, PIHOLE_IP
# Arguments:
#   None
#######################################
prompt_env() {
  echo -e "${BLUE}${ARROW} Setting up environment configuration...${NC}"
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${BLUE}  ${WRITE} .env Configuration${NC}"
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${YELLOW}Example Configuration:${NC}"
  echo -e "${YELLOW}  • ${GREEN}Timezone: Europe/Berlin${NC}"
  echo -e "${YELLOW}  • ${GREEN}Web Password: admin${NC}"
  echo -e "${YELLOW}  • ${GREEN}Web Port: 80${NC}"
  echo -e "${YELLOW}  • ${GREEN}Domain: local${NC}"
  echo -e "${YELLOW}  • ${GREEN}Web Theme: default-dark${NC}"
  echo -e "${YELLOW}  • ${GREEN}Hostname: pihole${NC}"
  echo -e "${YELLOW}  • ${GREEN}Pihole static IP (e.g. 192.168.10.20)${NC}"

  echo -e "${YELLOW}${WARNING} Use example config? [Y/n]: ${NC}\c"
  read -r USE_EXAMPLE

  if [[ "$USE_EXAMPLE" =~ ^[Nn]$ ]]; then
    echo -e "${BLUE}${ARROW} Custom configuration selected.${NC}"
    echo -ne "${YELLOW}Timezone (e.g. Europe/Berlin): ${NC}"
    read -r TZ
    echo -ne "${YELLOW}Web admin password: ${NC}"
    read -r WEBPASSWORD
    echo -ne "${YELLOW}Pihole Web-GUI port: ${NC}"
    read -r PIHOLE_WEBPORT
    echo -ne "${YELLOW}Domain name (e.g. local): ${NC}"
    read -r DOMAIN_NAME
    echo -ne "${YELLOW}Web theme (default-dark or default-light): ${NC}"
    read -r WEBTHEME
    echo -ne "${YELLOW}Hostname (e.g. pihole): ${NC}"
    read -r HOSTNAME
    echo -ne "${YELLOW}Pihole static IP (e.g. 192.168.10.20): ${NC}"
    read -r PIHOLE_IP
  else
    echo -e "${GREEN}Using example configuration...${NC}"
    TZ="Europe/Berlin"
    WEBPASSWORD="admin"
    PIHOLE_WEBPORT="80"
    DOMAIN_NAME="local"
    WEBTHEME="default-dark"
    HOSTNAME="pihole"
    PIHOLE_IP="192.168.10.20"
  fi

  echo -e "${GREEN}${WRITE} Creating .env file...${NC}"
  cat > .env <<EOF
TZ=$TZ
WEBPASSWORD=$WEBPASSWORD
PIHOLE_WEBPORT=$PIHOLE_WEBPORT
DOMAIN_NAME=$DOMAIN_NAME
WEBTHEME=$WEBTHEME
HOSTNAME=$HOSTNAME
PIHOLE_IP=$PIHOLE_IP
EOF
  echo -e "${GREEN}${CHECK} Environment configuration created successfully.${NC}"
}

#######################################
# Configure Docker macvlan network
# Globals:
#   GREEN, YELLOW, BLUE, ARROW, WARNING, NC
#   MACVLAN_PARENT, MACVLAN_SUBNET, MACVLAN_GATEWAY
# Arguments:
#   None
#######################################
prompt_macvlan() {
  echo -e "${BLUE}${ARROW} Setting up Docker Macvlan Network...${NC}"
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${BLUE}  🔌 Docker Macvlan Configuration${NC}"
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"

  echo -e "${GREEN}Available network interfaces:${NC}"
  ip -o link show | awk -F': ' '{print "  • "$2}' | grep -vE "lo|docker"

  echo -e "${YELLOW}${WARNING} Please configure your network settings:${NC}"
  echo -ne "${YELLOW}Select parent interface for macvlan (e.g. eth0): ${NC}"
  read -r MACVLAN_PARENT

  echo -ne "${YELLOW}Subnet (e.g. 192.168.10.0/24): ${NC}"
  read -r MACVLAN_SUBNET

  echo -ne "${YELLOW}Gateway (e.g. 192.168.10.1): ${NC}"
  read -r MACVLAN_GATEWAY

  echo -e "${GREEN}${CHECK} Network configuration completed.${NC}"
}


#######################################
# Create Docker macvlan network
# Globals:
#   GREEN, YELLOW, BLUE, ARROW, CHECK, WARNING, GEAR, NC
#   MACVLAN_SUBNET, MACVLAN_GATEWAY, MACVLAN_PARENT
# Arguments:
#   None
#######################################
create_macvlan_network() {
  echo -e "${BLUE}${ARROW} Creating macvlan network...${NC}"
  if ! docker network ls --format '{{.Name}}' | grep -q "^pihole_macvlan$"; then
    echo -e "${GREEN}${GEAR} Creating network with subnet=${MACVLAN_SUBNET}, gateway=${MACVLAN_GATEWAY}, parent=${MACVLAN_PARENT}${NC}"
    docker network create -d macvlan \
      --subnet=${MACVLAN_SUBNET} \
      --gateway=${MACVLAN_GATEWAY} \
      -o parent=${MACVLAN_PARENT} \
      pihole_macvlan
    echo -e "${GREEN}${CHECK} macvlan network 'pihole_macvlan' created successfully.${NC}"
  else
    echo -e "${YELLOW}${WARNING} macvlan network already exists - skipping creation.${NC}"
  fi
}

#######################################
# Generate docker-compose.yaml file
# Globals:
#   GREEN, YELLOW, BLUE, ARROW, CHECK, WRITE, NC, COMPOSE_FILE
#   PIHOLE_IP, HOSTNAME, TZ, WEBPASSWORD, WEBTHEME, DOMAIN_NAME, PIHOLE_WEBPORT
# Arguments:
#   None
#######################################
generate_compose() {
  echo -e "${BLUE}${ARROW} Generating ${COMPOSE_FILE}...${NC}"
  cat > ${COMPOSE_FILE} <<EOF
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
    restart: unless-stopped

networks:
  pihole_macvlan:
    external: true
EOF
  echo -e "${GREEN}${CHECK} ${COMPOSE_FILE} created successfully with Unbound volume mount.${NC}"
}

#######################################
# Start Docker containers
# Globals:
#   GREEN, YELLOW, BLUE, ARROW, CHECK, RESTART, NC
# Arguments:
#   None
#######################################
start_containers() {
  echo -e "${BLUE}${ARROW} Starting Docker containers...${NC}"
  if command -v docker-compose &>/dev/null; then
    echo -e "${GREEN}Using docker-compose to start containers...${NC}"
    docker-compose up -d
  elif command -v docker &>/dev/null && docker compose version &>/dev/null; then
    echo -e "${GREEN}Using docker compose plugin to start containers...${NC}"
    docker compose up -d
  fi
  echo -e "${GREEN}${CHECK} Containers started successfully.${NC}"
}

#######################################
# Print success message and connection information
# Globals:
#   GREEN, YELLOW, BLUE, NC, PIHOLE_IP, PIHOLE_WEBPORT, HOST_IP, PORTAINER_INSTALLED
# Arguments:
#   None
#######################################
print_success() {
  echo
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${GREEN}🎉 Pi-hole  Unbound is now up and running!${NC}"
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"

  echo -e "${BLUE}${ARROW} Access Details:${NC}"
  echo -e "${YELLOW}📍 Pihole Web-GUI:${NC} ${GREEN}http://${PIHOLE_IP}:${PIHOLE_WEBPORT}${NC}"
  echo -e "${YELLOW}🔑 Login Password:${NC} ${GREEN}In .env definiert${NC}"

  if [ "$PORTAINER_INSTALLED" = true ]; then
    echo -e "${YELLOW}🌐 Portainer WEB-GUI:${NC} ${GREEN}http://${HOST_IP}:9000${NC}"
  fi

  echo -e "${BLUE}${ARROW} Useful Commands:${NC}"
  echo -e "${YELLOW}${RESTART} Restart Container:${NC} ${GREEN}docker compose restart pihole-unbound${NC}"
  if [ "$PORTAINER_INSTALLED" = true ]; then
    echo -e "${YELLOW}${RESTART} Restart Portainer:${NC} ${GREEN}docker restart portainer${NC}"
  fi
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
}

#######################################
# Main function
# Globals:
#   All above variables and functions
# Arguments:
#   $@ - Command line arguments
#######################################
main() {
  print_header
  echo -e "${BLUE}${ARROW} Starting installation process...${NC}"

  # Check and install prerequisites
  detect_os
  check_docker || install_docker
  check_docker_compose || install_docker_compose

  echo -e "${BLUE}${ARROW} Checking for required tools...${NC}"
  check_command git || install_git_curl
  check_command curl || install_git_curl

  # Verify docker permissions
  CURRENT_USER=$(whoami)
  check_docker_group "$CURRENT_USER" || {
    add_user_to_docker_group "$CURRENT_USER"
    echo -e "${YELLOW}${WARNING} Please logout and login again, then rerun the script.${NC}"
    exit 0
  }

  # Clone and configure
  clone_repo
  cd "$REPO_DIR"

  # Setup components
  prompt_portainer
  prompt_env
  prompt_macvlan
  create_macvlan_network
  generate_compose

  # Start services
  echo -e "${BLUE}${ARROW} Finalizing installation...${NC}"
  start_containers
  print_success

  echo -e "${GREEN}${CHECK} Installation completed.${NC}"
}

main "$@"
