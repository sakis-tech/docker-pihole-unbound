#!/usr/bin/env bash
# ======================================================
# Unbound Host Configuration Setup Script
# Version: 1.2.1
# ======================================================
# This script configures Unbound DNS server to use a
# host-mounted configuration directory instead of storing
# configuration inside the container. This makes it easier
# to edit and maintain Unbound configuration files.
# ======================================================

set -euo pipefail

# Colors and formatting
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Icons for better readability
CHECK="✅"
CROSS="❌"
GEAR="⚙️"
FOLDER="📁"
FILE="📄"
SEARCH="🔍"
WRITE="✏️"
RESTART="🔄"
WARNING="⚠️"
QUESTION="❓"
ARROW="▶"

# Configuration variables
CONTAINER="pihole-unbound"
UNBOUND_DIR="/etc/unbound"
CONF_FILE="${UNBOUND_DIR}/unbound.conf.d/pi-hole.conf"
SCRIPT_VERSION="1.2.1"

#######################################
# Print header with script information
# Globals:
#   BLUE, GREEN, YELLOW, NC
# Arguments:
#   None
#######################################
print_header() {
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${BLUE}  🔒 Unbound Host Configuration Setup v${SCRIPT_VERSION}${NC}"
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${YELLOW}This script will:${NC}"
  echo -e "${GREEN}- Find your Pi-hole + Unbound installation directory${NC}"
  echo -e "${GREEN}- Create a host-based Unbound configuration directory${NC}"
  echo -e "${GREEN}- Update docker-compose.yaml to mount this directory${NC}"
  echo -e "${GREEN}- Enable easy editing of Unbound settings from the host${NC}"
  echo -e "${GREEN}- Restart the container to apply changes${NC}"
  echo

  # Show current installation directory if known
  if [ -n "${PWD##*/}" ]; then
    echo -e "${BLUE}Working directory: $(pwd)${NC}"
    echo
  fi
}

#######################################
# Ask for user confirmation before proceeding
# Globals:
#   YELLOW, RED, QUESTION, CROSS, NC
# Arguments:
#   None
# Returns:
#   0 if user confirms, exits script if not
#######################################
confirm_setup() {
  echo -e "${YELLOW}${QUESTION} Do you want to continue with setup? [y/N]${NC}"
  read -r response
  case "$response" in
    [yY][eE][sS]|[yY]) 
      return 0
      ;;
    *)
      echo -e "${RED}${CROSS} Setup canceled.${NC}"
      exit 0
      ;;
  esac
}

#######################################
# Find the installation directory with docker-compose.yaml
# Attempts multiple methods to locate the installation
# Globals:
#   GREEN, RED, YELLOW, CHECK, CROSS, SEARCH, NC, CONTAINER
# Arguments:
#   None
# Returns:
#   0 if found, 1 if not found
#######################################
find_install_dir() {
  echo -e "${BLUE}${ARROW} Searching for Pi-hole + Unbound installation directory...${NC}"
  
  # Check current directory first
  if [ -f "./docker-compose.yml" ] || [ -f "./docker-compose.yaml" ]; then
    echo -e "${GREEN}${CHECK} Found installation in current directory.${NC}"
    return 0
  fi
  
  # Check for typical installation paths
  local typical_paths=(
    "$HOME/docker-pihole-unbound"
    "$HOME/pihole-unbound"
    "/opt/pihole-unbound"
    "/opt/docker/pihole-unbound"
    "$HOME/Documents/docker-pihole-unbound"
  )
  
  for path in "${typical_paths[@]}"; do
    if [ -d "$path" ] && ([ -f "$path/docker-compose.yml" ] || [ -f "$path/docker-compose.yaml" ]); then
      echo -e "${GREEN}${CHECK} Found installation in $path${NC}"
      cd "$path"
      return 0
    fi
  done
  
  # Find by container name using Docker metadata - with better error handling
  if command -v docker &>/dev/null; then
    # Method 1: Try to get project directory from container labels
    local container_dir
    container_dir=$(docker inspect --format='{{.Config.Labels.com.docker.compose.project.working_dir}}' "${CONTAINER}" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$container_dir" ] && [ "$container_dir" != "<no value>" ] && [ -d "$container_dir" ]; then
      echo -e "${GREEN}${CHECK} Found installation in $container_dir based on container metadata.${NC}"
      cd "$container_dir"
      return 0
    fi
    
    # Method 2: Get the mount source path for the config volume
    local config_path
    config_path=$(docker inspect --format='{{range .Mounts}}{{if eq .Destination "/etc/pihole"}}{{.Source}}{{end}}{{end}}' "${CONTAINER}" 2>/dev/null)
    if [ -n "$config_path" ] && [ -d "$(dirname "$(dirname "$config_path")")" ]; then
      local install_path=$(dirname "$(dirname "$config_path")")
      echo -e "${GREEN}${CHECK} Found installation in $install_path based on volume mounts.${NC}"
      cd "$install_path"
      return 0
    fi

    # Method 3: Search for docker-compose with this container
    echo -e "${YELLOW}• Searching for docker-compose files containing container name...${NC}"
    local compose_files=$(find $HOME -maxdepth 5 -name "docker-compose.y*ml" -type f -exec grep -l "${CONTAINER}" {} \; 2>/dev/null)
    if [ -n "$compose_files" ]; then
      local first_file=$(echo "$compose_files" | head -n 1)
      local dir_path=$(dirname "$first_file")
      echo -e "${GREEN}${CHECK} Found installation in $dir_path by searching docker-compose files.${NC}"
      cd "$dir_path"
      return 0
    fi
    
    # Method 4: Try to deduce from container name and network settings
    echo -e "${YELLOW}• Checking container network settings...${NC}"
    local network_name="pihole_macvlan"
    local networks=$(docker network ls --format '{{.Name}}' | grep -E "(pihole|unbound)")
    if [ -n "$networks" ]; then
      local network_path="/var/lib/docker/volumes"
      if [ -d "$network_path" ]; then
        echo -e "${YELLOW}• Found potential Docker networks: $networks${NC}"
        # We could try to follow network references here if needed
      fi
    fi
  else
    echo -e "${YELLOW}${WARNING} Docker command not found, skipping container-based detection.${NC}"
  fi
  
  # Last resort: Ask user for the path
  echo -e "${YELLOW}${WARNING} Could not find installation directory automatically.${NC}"
  echo -e "${YELLOW}• Please enter the path to your Pi-hole installation directory:${NC}"
  read -r custom_path
  
  if [ -n "$custom_path" ] && [ -d "$custom_path" ]; then
    cd "$custom_path"
    echo -e "${GREEN}${CHECK} Using provided path: $custom_path${NC}"
    return 0
  fi
  
  echo -e "${RED}${CROSS} Could not find installation directory.${NC}"
  return 1
}

# Global variables for paths will be set in main()

#######################################
# Check if Docker container is running
# Globals:
#   RED, CROSS, GEAR, NC, CONTAINER
# Arguments:
#   None
# Returns:
#   0 if running, exits script if not running
#######################################
check_container() {
  echo -e "${BLUE}▶ Checking if container '${CONTAINER}' is running...${NC}"
  if ! command -v docker &>/dev/null; then
    echo -e "${RED}${CROSS} Docker is not installed or not in PATH.${NC}"
    exit 1
  fi
  
  if ! docker ps --format '{{.Names}}' | grep -qw "${CONTAINER}"; then
    echo -e "${RED}${CROSS} Container '${CONTAINER}' is not running.${NC}"
    echo -e "${YELLOW}Please start the container first with 'docker-compose up -d' and then run this script again.${NC}"
    exit 1
  fi
  
  echo -e "${GREEN}${CHECK} Container '${CONTAINER}' is running.${NC}"
}

#######################################
# Create host configuration directory
# Globals:
#   GREEN, CHECK, FOLDER, NC, HOST_UNBOUND_CONF_DIR
# Arguments:
#   None
#######################################
create_config_dir() {
  echo -e "${BLUE}${ARROW} Creating Unbound configuration directory on host...${NC}"
  
  # Check if sudo is needed
  if [ ! -w "$HOST_CONFIG_DIR" ] && [ -d "$HOST_CONFIG_DIR" ]; then
    echo -e "${YELLOW}${WARNING} Permission issue detected. Trying with sudo...${NC}"
    if command -v sudo &>/dev/null; then
      sudo mkdir -p "${HOST_UNBOUND_CONF_DIR}"
      # Fix ownership
      sudo chown -R $(whoami):$(id -gn) "${HOST_CONFIG_DIR}"
      echo -e "${GREEN}${CHECK} Created directory with sudo: ${HOST_UNBOUND_CONF_DIR}${NC}"
    else
      echo -e "${RED}${CROSS} Cannot create directory due to permissions.${NC}"
      echo -e "${YELLOW}${INFO} Please run this script with sudo.${NC}"
      exit 1
    fi
  else
    mkdir -p "${HOST_UNBOUND_CONF_DIR}"
    echo -e "${GREEN}${CHECK} Created directory: ${HOST_UNBOUND_CONF_DIR}${NC}"
  fi
}

#######################################
# Copy configuration from container
# Globals:
#   GREEN, YELLOW, FILE, CHECK, NC, CONTAINER, CONF_FILE, HOST_UNBOUND_CONF_DIR
# Arguments:
#   None
#######################################
copy_config() {
  echo -e "${BLUE}${ARROW} Copying Unbound configuration from container...${NC}"
  
  # Check if the file exists in the container
  if ! docker exec "${CONTAINER}" test -f "${CONF_FILE}" 2>/dev/null; then
    echo -e "${RED}${CROSS} Configuration file not found in container at ${CONF_FILE}${NC}"
    echo -e "${YELLOW}${WARNING} Please check if the container image is correct.${NC}"
    return 1
  fi
  
  # Copy the file from container to host
  if [ ! -f "${HOST_UNBOUND_CONF_DIR}/pi-hole.conf" ]; then
    echo -e "${YELLOW}• Copying configuration from container to host...${NC}"
    if docker cp "${CONTAINER}:${CONF_FILE}" "${HOST_UNBOUND_CONF_DIR}/pi-hole.conf" 2>/dev/null; then
      echo -e "${GREEN}${CHECK} Successfully copied Unbound configuration file.${NC}"
    else
      echo -e "${YELLOW}${WARNING} Permission issue copying file. Trying with sudo...${NC}"
      if command -v sudo &>/dev/null; then
        docker cp "${CONTAINER}:${CONF_FILE}" - | sudo tee "${HOST_UNBOUND_CONF_DIR}/pi-hole.conf" > /dev/null
        sudo chown $(whoami):$(id -gn) "${HOST_UNBOUND_CONF_DIR}/pi-hole.conf"
        echo -e "${GREEN}${CHECK} Successfully copied file using sudo.${NC}"
      else
        echo -e "${RED}${CROSS} Could not copy file due to permissions.${NC}"
        return 1
      fi
    fi
  else
    echo -e "${YELLOW}${WARNING} Unbound configuration file already exists on host.${NC}"
  fi
}

#######################################
# Find docker-compose file
# Globals:
#   GREEN, RED, YELLOW, CHECK, CROSS, NC
# Arguments:
#   None
# Returns:
#   Sets COMPOSE_FILE global variable
#######################################
find_compose_file() {
  echo -e "${BLUE}${ARROW} Looking for docker-compose file...${NC}"
  COMPOSE_FILE="./docker-compose.yaml"
  if [ ! -f "${COMPOSE_FILE}" ]; then
    COMPOSE_FILE="./docker-compose.yml"
    if [ ! -f "${COMPOSE_FILE}" ]; then
      echo -e "${RED}${CROSS} Docker-compose file not found!${NC}"
      echo -e "${YELLOW}Please make sure you are in the installation directory.${NC}"
      exit 1
    fi
  fi

  echo -e "${GREEN}${CHECK} Found docker-compose file: ${COMPOSE_FILE}${NC}"
}

#######################################
# Modify docker-compose to add volume mount
# Globals:
#   GREEN, RED, YELLOW, GEAR, CHECK, CROSS, NC, HOST_UNBOUND_DIR, UNBOUND_DIR, COMPOSE_FILE
# Arguments:
#   None
#######################################
modify_docker_compose() {
  echo -e "${BLUE}${ARROW} Updating docker-compose configuration...${NC}"
  
  # Create temporary file
  local TMP_COMPOSE_FILE=$(mktemp)
  
  # Check if the Unbound mount already exists
  if grep -q "${HOST_UNBOUND_DIR}:${UNBOUND_DIR}" "${COMPOSE_FILE}"; then
    echo -e "${YELLOW}${WARNING} Unbound volume mount already exists in docker-compose.${NC}"
    cp "${COMPOSE_FILE}" "${TMP_COMPOSE_FILE}"
  else
    # First attempt: Add mount after existing volume entries
    sed '/volumes:/,/restart:/ {
      /volumes:/ b print
      /restart:/ b print
      /volumes:/ {
        N
        s/\(      - .*:rw\)/\1\n      - .\2config\2unbound:\/etc\2unbound:rw/
      }
      b
      : print
      p
    }' "${COMPOSE_FILE}" > "${TMP_COMPOSE_FILE}" 2>/dev/null || cp "${COMPOSE_FILE}" "${TMP_COMPOSE_FILE}"
    
    # If no changes were made, try another approach
    if ! grep -q "${HOST_UNBOUND_DIR}:${UNBOUND_DIR}" "${TMP_COMPOSE_FILE}"; then
      # Second attempt: Add mount right after volumes:
      awk '/volumes:/ { 
        print $0; 
        print "      - ./config/unbound:/etc/unbound:rw"; 
        next 
      } { print }' "${COMPOSE_FILE}" > "${TMP_COMPOSE_FILE}"
    fi
    
    # Check if the change was successful
    if grep -q "${HOST_UNBOUND_DIR}:${UNBOUND_DIR}" "${TMP_COMPOSE_FILE}"; then
      cp "${TMP_COMPOSE_FILE}" "${COMPOSE_FILE}"
      echo -e "${GREEN}${CHECK} Successfully updated docker-compose configuration.${NC}"
    else
      echo -e "${RED}${CROSS} Could not automatically update docker-compose file.${NC}"
      echo -e "${YELLOW}Please manually add the following line under 'volumes:' section:${NC}"
      echo -e "${YELLOW}      - ./config/unbound:/etc/unbound:rw${NC}"
    fi
  fi
  
  # Clean up temporary file
  rm -f "${TMP_COMPOSE_FILE}"
}

#######################################
# Restart the Docker container
# Globals:
#   GREEN, YELLOW, RESTART, CHECK, NC, CONTAINER
# Arguments:
#   None
#######################################
restart_container() {
  echo -e "${BLUE}${ARROW} Restarting container to apply changes...${NC}"
  
  if command -v docker-compose &>/dev/null; then
    echo -e "${GREEN}Using docker-compose to restart containers...${NC}"
    docker-compose down && docker-compose up -d
  elif command -v docker &>/dev/null && docker compose version &>/dev/null; then
    echo -e "${GREEN}Using docker compose plugin to restart containers...${NC}"
    docker compose down && docker compose up -d
  else
    echo -e "${YELLOW}${WARNING} Could not find docker-compose or docker compose plugin.${NC}"
    echo -e "${YELLOW}Please restart the container manually:${NC}"
    echo -e "${YELLOW}   docker-compose down && docker-compose up -d${NC}"
    return 1
  fi
  
  echo -e "${GREEN}${CHECK} Container successfully restarted.${NC}"
  return 0
}

#######################################
# Print summary of actions performed
# Globals:
#   BLUE, GREEN, YELLOW, NC, HOST_UNBOUND_CONF_DIR, CONTAINER
# Arguments:
#   None
#######################################
print_summary() {
  echo
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${GREEN}${CHECK} Unbound host configuration has been successfully set up!${NC}"
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${BLUE}${ARROW} Configuration Information:${NC}"
  echo -e "${YELLOW}${WRITE} You can now edit the Unbound configuration at:${NC}"
  echo -e "${YELLOW}    ${HOST_UNBOUND_CONF_DIR}/pi-hole.conf${NC}"
  echo
  echo -e "${BLUE}${ARROW} Next Steps:${NC}"
  echo -e "${YELLOW}${RESTART} After changing the configuration, restart the container:${NC}"
  echo -e "${YELLOW}    docker-compose restart ${CONTAINER}${NC}"
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
}

#######################################
# Main function - orchestrates the setup process
# Globals:
#   None
# Arguments:
#   None
#######################################
main() {
  # Print header information and find installation directory
  print_header
  find_install_dir || {
    echo -e "${RED}${CROSS} Could not automatically find the installation directory.${NC}"
    echo -e "${YELLOW}Please navigate to your Pi-hole + Unbound installation directory and try again.${NC}"
    exit 1
  }
  
  # Define paths after finding the correct directory
  HOST_CONFIG_DIR="./config"
  HOST_UNBOUND_DIR="${HOST_CONFIG_DIR}/unbound"
  HOST_UNBOUND_CONF_DIR="${HOST_UNBOUND_DIR}/unbound.conf.d"
  
  # Ask for user confirmation before proceeding
  confirm_setup
  
  # Run all the setup steps in sequence
  check_container
  create_config_dir
  copy_config
  find_compose_file
  modify_docker_compose
  restart_container
  print_summary
}

# Run the main function
main
