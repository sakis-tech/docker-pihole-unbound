#!/usr/bin/env bash
#######################################
# Pi-hole + Unbound Auto-Installer
# Version: 1.0
#
# Description: This script automates the installation of Pi-hole with Unbound DNS resolver
# running in a Docker container. It handles prerequisites installation, network configuration,
# and container setup.
#
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
  
  # Create env content in a variable first
  local env_content="TZ=$TZ
WEBPASSWORD=$WEBPASSWORD
PIHOLE_WEBPORT=$PIHOLE_WEBPORT
DOMAIN_NAME=$DOMAIN_NAME
WEBTHEME=$WEBTHEME
HOSTNAME=$HOSTNAME
PIHOLE_IP=$PIHOLE_IP"

  # Try writing to file, with fallbacks for permissions
  if ! echo "$env_content" > .env 2>/dev/null; then
    echo -e "${YELLOW}${WARNING} Permission issue creating .env file. Trying with sudo...${NC}"
    if command -v sudo &>/dev/null; then
      echo "$env_content" | sudo tee .env > /dev/null
      # Fix ownership if using sudo
      sudo chown $(whoami):$(id -gn) .env
    else
      echo -e "${RED}${CROSS} Could not create .env file due to permissions.${NC}"
      echo -e "${YELLOW}${INFO} Please run this script with appropriate permissions.${NC}"
      exit 1
    fi
  fi
  
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
  
  # Create compose content in a variable first
  local compose_content="services:
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
      - ./config/unbound:/etc/unbound:rw
    restart: unless-stopped

networks:
  pihole_macvlan:
    external: true"

  # Try writing to file, with fallbacks for permissions
  if ! echo "$compose_content" > "${COMPOSE_FILE}" 2>/dev/null; then
    echo -e "${YELLOW}${WARNING} Permission issue creating ${COMPOSE_FILE}. Trying with sudo...${NC}"
    if command -v sudo &>/dev/null; then
      echo "$compose_content" | sudo tee "${COMPOSE_FILE}" > /dev/null
      # Fix ownership if using sudo
      sudo chown $(whoami):$(id -gn) "${COMPOSE_FILE}"
    else
      echo -e "${RED}${CROSS} Could not create ${COMPOSE_FILE} due to permissions.${NC}"
      echo -e "${YELLOW}${INFO} Please run this script with appropriate permissions.${NC}"
      exit 1
    fi
  fi
  
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
  
  # Create required directories first with proper permissions
  echo -e "${YELLOW}• Creating configuration directories...${NC}"
  
  # Check if sudo is needed
  if [ ! -w "./config" ] && [ -d "./config" ]; then
    local use_sudo=true
  elif [ ! -d "./config" ] && [ ! -w "." ]; then
    local use_sudo=true
  else
    local use_sudo=false
  fi
  
  # Create directories with proper permissions
  if $use_sudo; then
    echo -e "${YELLOW}• Using sudo for directory creation${NC}"
    sudo mkdir -p ./config/pihole
    sudo mkdir -p ./config/unbound
    # Fix ownership
    sudo chown -R $(whoami):$(id -gn) ./config
  else
    mkdir -p ./config/pihole
    mkdir -p ./config/unbound
  fi
  
  # Start the containers
  if command -v docker-compose &>/dev/null; then
    echo -e "${YELLOW}• Using docker-compose to start containers...${NC}"
    docker-compose up -d
  elif command -v docker &>/dev/null && docker compose version &>/dev/null; then
    echo -e "${YELLOW}• Using docker compose plugin to start containers...${NC}"
    docker compose up -d
  fi
  
  # Check if containers started successfully
  if docker ps | grep -q "pihole-unbound"; then
    echo -e "${GREEN}${CHECK} Containers started successfully.${NC}"
  else
    echo -e "${RED}${CROSS} Container failed to start. Check permissions and Docker configuration.${NC}"
  fi
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
# Cleans up the repository, leaving only essential files
# Globals:
#   None
# Arguments:
#   None
#######################################
cleanup_files() {
  echo -e "${BLUE}${ARROW} Cleaning up repository files...${NC}"
  
  # First ensure we're in the correct directory
  local install_dir=""
  
  # Check if the docker-compose file exists in current directory
  if [ -f "./docker-compose.yaml" ] || [ -f "./docker-compose.yml" ]; then
    install_dir="$(pwd)"
  # Check if REPO_DIR is set and valid
  elif [ -n "$REPO_DIR" ] && [ -d "$REPO_DIR" ]; then
    install_dir="$REPO_DIR"
    cd "$REPO_DIR"
  # Try to find installation directory from running container
  else
    if command -v docker &>/dev/null && docker ps -q -f name=pihole-unbound &>/dev/null; then
      local config_path
      config_path=$(docker inspect --format='{{range .Mounts}}{{if eq .Destination "/etc/pihole"}}{{.Source}}{{end}}{{end}}' "pihole-unbound" 2>/dev/null)
      if [ -n "$config_path" ] && [ -d "$(dirname "$(dirname "$config_path")")" ]; then
        install_dir=$(dirname "$(dirname "$config_path")")
        cd "$install_dir"
      fi
    fi
  fi
  
  # If we still can't find the installation directory, exit gracefully
  if [ -z "$install_dir" ] || [ ! -d "$install_dir" ]; then
    echo -e "${YELLOW}${WARNING} Could not locate installation directory for cleanup.${NC}"
    echo -e "${YELLOW}${INFO} Manual cleanup required: Keep only docker-compose.yaml, .env, and config/ directory.${NC}"
    return 1
  fi
  
  echo -e "${YELLOW}• Found installation in: ${install_dir}${NC}"
  
  # Check for sudo privileges
  local use_sudo=false
  if [ "$(id -u)" -eq 0 ]; then
    # Already running as root
    use_sudo=false
  elif command -v sudo &>/dev/null; then
    # Can use sudo
    use_sudo=true
  fi
  
  # Create a temporary directory for backup just in case
  local backup_dir="${install_dir}/backup_$(date +%Y%m%d%H%M%S)"
  if $use_sudo; then
    sudo mkdir -p "$backup_dir"
  else
    mkdir -p "$backup_dir"
  fi
  
  # Helper function to copy files with proper permissions handling
  copy_with_permissions() {
    local src="$1"
    local dst="$2"
    
    if [ ! -e "$src" ]; then
      return 1
    fi
    
    if $use_sudo; then
      sudo cp -r "$src" "$dst"
    else
      cp -r "$src" "$dst" 2>/dev/null || {
        echo -e "${YELLOW}${WARNING} Permission issue copying ${src}. Trying with sudo...${NC}"
        if command -v sudo &>/dev/null; then
          sudo cp -r "$src" "$dst"
        else
          echo -e "${RED}${CROSS} Could not copy ${src}. Continuing anyway.${NC}"
        fi
      }
    fi
    return 0
  }
  
  # Copy essential files to backup
  echo -e "${YELLOW}• Backing up essential files...${NC}"
  if [ -f "${install_dir}/docker-compose.yaml" ]; then
    copy_with_permissions "${install_dir}/docker-compose.yaml" "${backup_dir}/"
  elif [ -f "${install_dir}/docker-compose.yml" ]; then
    copy_with_permissions "${install_dir}/docker-compose.yml" "${backup_dir}/"
  else
    echo -e "${YELLOW}${WARNING} docker-compose file not found, skipping backup.${NC}"
  fi
  
  if [ -f "${install_dir}/.env" ]; then
    copy_with_permissions "${install_dir}/.env" "${backup_dir}/"
  else
    echo -e "${YELLOW}${WARNING} .env file not found, skipping backup.${NC}"
  fi
  
  if [ -d "${install_dir}/config" ]; then
    echo -e "${YELLOW}• Backing up config directory...${NC}"
    copy_with_permissions "${install_dir}/config" "${backup_dir}/"
  else
    mkdir -p "${backup_dir}/config"
    echo -e "${YELLOW}${WARNING} config directory not found, creating empty one.${NC}"
  fi
  
  # Remove everything except backup dir
  echo -e "${YELLOW}• Removing unnecessary files...${NC}"
  if $use_sudo; then
    sudo find "${install_dir}" -mindepth 1 -not -path "${backup_dir}" -not -path "${backup_dir}/*" -exec rm -rf {} \; 2>/dev/null || true
  else
    find "${install_dir}" -mindepth 1 -not -path "${backup_dir}" -not -path "${backup_dir}/*" -exec rm -rf {} \; 2>/dev/null || true
  fi
  
  # Move essential files back
  echo -e "${YELLOW}• Restoring essential files...${NC}"
  if [ -f "${backup_dir}/docker-compose.yaml" ]; then
    copy_with_permissions "${backup_dir}/docker-compose.yaml" "${install_dir}/"
  elif [ -f "${backup_dir}/docker-compose.yml" ]; then
    copy_with_permissions "${backup_dir}/docker-compose.yml" "${install_dir}/"
  fi
  
  if [ -f "${backup_dir}/.env" ]; then
    copy_with_permissions "${backup_dir}/.env" "${install_dir}/"
  fi
  
  if [ -d "${backup_dir}/config" ]; then
    copy_with_permissions "${backup_dir}/config" "${install_dir}/"
  fi
  
  # Remove backup dir
  echo -e "${YELLOW}• Removing temporary backup...${NC}"
  if $use_sudo; then
    sudo rm -rf "${backup_dir}"
  else
    rm -rf "${backup_dir}"
  fi
  
  # Ensure proper directory structure exists
  echo -e "${YELLOW}• Ensuring proper directory structure...${NC}"
  if $use_sudo; then
    sudo mkdir -p "${install_dir}/config/pihole"
    sudo mkdir -p "${install_dir}/config/unbound"
  else
    mkdir -p "${install_dir}/config/pihole"
    mkdir -p "${install_dir}/config/unbound"
  fi
  
  echo -e "${GREEN}${CHECK} Repository cleaned up, leaving only essential files:${NC}"
  echo -e "${YELLOW}• docker-compose.yaml${NC}"
  echo -e "${YELLOW}• .env${NC}"
  echo -e "${YELLOW}• config/pihole/${NC}"
  echo -e "${YELLOW}• config/unbound/${NC}"
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
  
  # Clean up repository, leaving only essential files
  cleanup_files

  echo -e "${GREEN}${CHECK} Installation completed.${NC}"
}

main "$@"
