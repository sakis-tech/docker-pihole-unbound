#!/bin/bash
# =============================================================================
# Pi-hole + Unbound Host Configuration Setup Script
# Enables DNSSEC and custom unbound configurations
# 
# Designed to work with Docker Named Volumes environment
# =============================================================================

# Version number
VERSION="1.2.5"

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Initial detection of docker compose command
DOCKER_COMPOSE_CMD="docker-compose"
if ! command -v docker-compose &>/dev/null && command -v docker &>/dev/null && docker compose version &>/dev/null; then
  DOCKER_COMPOSE_CMD="docker compose"
fi

# Define container name
CONTAINER="pihole-unbound"
#######################################
# Print script header
# Globals:
#   BLUE, NC, VERSION
# Arguments:
#   None
#######################################
print_header() {
  clear
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}🔒 Unbound Host Configuration Setup v${VERSION}${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "This script will automatically:"
  echo -e "${GREEN}• Find your Pi-hole + Unbound installation directory${NC}"
  echo -e "${GREEN}• Create a host-based Unbound configuration directory${NC}"
  echo -e "${GREEN}• Update docker-compose.yaml to mount this directory${NC}"
  echo -e "${GREEN}• Enable easy editing of Unbound settings from the host${NC}"
  echo -e "${GREEN}• Restart the container to apply changes${NC}"
  echo
  echo -e "Working directory: $(pwd)"
  echo
}

#######################################
# Find the installation directory
# Globals:
#   BLUE, GREEN, RED, ARROW, CHECK, CROSS, NC
# Arguments:
#   None
# Returns:
#   0 if directory found, 1 otherwise
#######################################
find_install_dir() {
  echo -e "${BLUE}${GEAR} Searching for Pi-hole + Unbound installation directory...${NC}"

  # Check current directory first
  local CURRENT_DIR=$(pwd)
  if [ -f "$CURRENT_DIR/docker-compose.yaml" ] || [ -f "$CURRENT_DIR/docker-compose.yml" ]; then
    if grep -q "$CONTAINER" "$CURRENT_DIR/docker-compose.yaml" 2>/dev/null || grep -q "$CONTAINER" "$CURRENT_DIR/docker-compose.yml" 2>/dev/null; then
      echo -e "${GREEN}${CHECK} Found installation in ${CURRENT_DIR}${NC}"
      return 0
    fi
  fi

  # Try to deduce from Docker container mounts
  if command -v docker &>/dev/null; then
    if docker ps -q -f name="$CONTAINER" &>/dev/null; then
      # Container exists, check for volumes
      local COMPOSE_PATH=$(docker inspect --format='{{range .Mounts}}{{if eq .Type "bind"}}{{if eq .Destination "/etc/pihole"}}{{.Source}}{{end}}{{end}}{{end}}' "$CONTAINER" 2>/dev/null)
      
      if [ -n "$COMPOSE_PATH" ]; then
        COMPOSE_PATH="${COMPOSE_PATH%/config/pihole}" # Remove trailing /config/pihole if present
        
        if [ -f "$COMPOSE_PATH/docker-compose.yaml" ] || [ -f "$COMPOSE_PATH/docker-compose.yml" ]; then
          echo -e "${GREEN}${CHECK} Found installation in ${COMPOSE_PATH}${NC}"
          cd "$COMPOSE_PATH" || return 1
          return 0
        fi
      fi
    fi

    # Search for docker-compose files in common locations
    local COMMON_PATHS=("/opt" "/usr/local" "$HOME" "/srv" "/var/lib")
    for path in "${COMMON_PATHS[@]}"; do
      if [ -d "$path" ]; then
        # Find docker-compose files with the container name in them
        local FOUND_PATHS=$(find "$path" -name "docker-compose.y*ml" -type f -exec grep -l "$CONTAINER" {} \; 2>/dev/null)
        
        if [ -n "$FOUND_PATHS" ]; then
          # Take the first match
          local COMPOSE_PATH=$(echo "$FOUND_PATHS" | head -n 1)
          COMPOSE_PATH="${COMPOSE_PATH%/*}" # Get directory
          
          echo -e "${GREEN}${CHECK} Found installation in ${COMPOSE_PATH}${NC}"
          cd "$COMPOSE_PATH" || return 1
          return 0
        fi
      fi
    done
  fi

  # If we reach here, we couldn't find it automatically
  # Ask user for the path
  echo -e "${YELLOW}${WARNING} Could not automatically find the installation directory.${NC}"
  read -rp "Please specify the full path to the Pi-hole + Unbound directory: " USER_PATH
  
  if [ -z "$USER_PATH" ]; then
    echo -e "${RED}${CROSS} No path provided.${NC}"
    return 1
  fi
  
  if [ -d "$USER_PATH" ]; then
    cd "$USER_PATH" || return 1
    echo -e "${GREEN}${CHECK} Using user-specified directory: ${USER_PATH}${NC}"
    return 0
  else
    echo -e "${RED}${CROSS} Directory not found: ${USER_PATH}${NC}"
    return 1
  fi
}
#######################################
# Request confirmation to continue
# Globals:
#   YELLOW, NC, WARNING
# Arguments:
#   None
#######################################
confirm_setup() {
  echo -e "${YELLOW}❓ Do you want to continue with setup? [Y/n]${NC}"
  read -r CONTINUE

  if [[ "$CONTINUE" =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}Setup canceled.${NC}"
    exit 0
  else
    return 0
  fi
}

#######################################
# Check if the Docker container is running
# Globals:
#   BLUE, GREEN, RED, ARROW, CHECK, CROSS, NC, CONTAINER
# Arguments:
#   None
#######################################
check_container() {
  echo -e "${BLUE}${GEAR} Checking if container '${CONTAINER}' is running...${NC}"
  
  if command -v docker &>/dev/null; then
    if docker ps -q -f name="$CONTAINER" &>/dev/null; then
      echo -e "${GREEN}${CHECK} Container '${CONTAINER}' is running.${NC}"
      return 0
    else
      echo -e "${RED}${CROSS} Container '${CONTAINER}' is not running.${NC}"
      echo -e "${YELLOW}Please make sure the container is running and try again.${NC}"
      exit 1
    fi
  else
    echo -e "${RED}${CROSS} Docker is not installed or not in PATH.${NC}"
    exit 1
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
  echo -e "${BLUE}${GEAR} Looking for docker-compose file...${NC}"
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
# Modify docker-compose to add volume mount for Named Volumes setup
# Globals:
#   GREEN, RED, YELLOW, GEAR, CHECK, CROSS, NC, HOST_UNBOUND_DIR, UNBOUND_DIR, COMPOSE_FILE
# Arguments:
#   None
#######################################
modify_docker_compose() {
  echo -e "${BLUE}${GEAR} Updating docker-compose configuration...${NC}"

  # Create temporary file and backup
  local TMP_COMPOSE_FILE=$(mktemp)
  cp "${COMPOSE_FILE}" "${COMPOSE_FILE}.bak"
  
  # Check if docker-compose uses named volumes (new format)
  if grep -q "volumes:" "${COMPOSE_FILE}" && grep -q "  pihole:" "${COMPOSE_FILE}"; then
    # Named volumes format detected
    
    # Check if the Unbound mount already exists
    if grep -q "${HOST_UNBOUND_DIR}:/etc/unbound/custom.conf.d:rw" "${COMPOSE_FILE}"; then
      echo -e "${YELLOW}${WARNING} Unbound volume mount already exists in docker-compose.${NC}"
      return 0
    else
      # Find the volumes section within the service and add our mount
      awk '/volumes:/ && !v {
        print $0;
        print "      - ./unbound:/etc/unbound/custom.conf.d:rw";
        v=1;
        next
      }
      { print }' "${COMPOSE_FILE}" > "${TMP_COMPOSE_FILE}"
      
      # Copy changes back to original file
      cp "${TMP_COMPOSE_FILE}" "${COMPOSE_FILE}"
      echo -e "${GREEN}${CHECK} Successfully updated docker-compose configuration with custom Unbound volume.${NC}"
      return 0
    fi
  else
    # For older format without Named Volumes
    echo -e "${YELLOW}${WARNING} Your docker-compose.yaml doesn't use named volumes format.${NC}"
    echo -e "${YELLOW}${WARNING} Please update your installation by running the install script again.${NC}"
    echo -e "${YELLOW}${WARNING} Alternatively, add this line to your docker-compose.yaml volumes section:${NC}"
    echo -e "${YELLOW}      - ${HOST_UNBOUND_DIR}:/etc/unbound/custom.conf.d:rw${NC}"
    return 1
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
  echo -e "${BLUE}${GEAR} Restarting container to apply changes...${NC}"

  if command -v docker-compose &>/dev/null; then
    echo -e "${GREEN}Using docker-compose to restart containers...${NC}"
    docker-compose restart ${CONTAINER}
  elif command -v docker &>/dev/null && docker compose version &>/dev/null; then
    echo -e "${GREEN}Using docker compose plugin to restart containers...${NC}"
    docker compose restart ${CONTAINER}
  else
    echo -e "${YELLOW}${WARNING} Could not find docker-compose or docker compose plugin.${NC}"
    echo -e "${YELLOW}Please restart the container manually:${NC}"
    echo -e "${YELLOW}   docker restart ${CONTAINER}${NC}"
    return 1
  fi

  echo -e "${GREEN}${CHECK} Container successfully restarted.${NC}"
  return 0
}

#######################################
# Print summary of actions performed
# Globals:
#   BLUE, GREEN, YELLOW, NC, HOST_UNBOUND_DIR, CONTAINER
# Arguments:
#   None
#######################################
print_custom_summary() {
  echo
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}${CHECK} Unbound custom configuration has been successfully set up!${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}${GEAR} Configuration Information:${NC}"
  echo -e "${YELLOW}${WRITE} You can now edit the Unbound custom configuration at:${NC}"
  echo -e "${YELLOW}    ${HOST_UNBOUND_DIR}/custom.conf${NC}"
  echo -e "${YELLOW}    This file is mounted to ${UNBOUND_DIR} in the container${NC}"
  echo
  echo -e "${BLUE}${GEAR} Next Steps:${NC}"
  echo -e "${YELLOW}${RESTART} After changing the configuration, restart the container:${NC}"
  echo -e "${YELLOW}    docker-compose restart ${CONTAINER}${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
  # Create local custom unbound config directory
  HOST_UNBOUND_DIR="./unbound"
  UNBOUND_DIR="/etc/unbound/custom.conf.d"
  
  # Ask for user confirmation before proceeding
  confirm_setup
  
  # Get the current user for later use
  CURRENT_USER="$(logname 2>/dev/null || echo $USER)"
  CURRENT_GROUP="$(id -gn "$CURRENT_USER" 2>/dev/null || echo "$CURRENT_USER")"
  
  # In case we couldn't determine the user
  if [ -z "$CURRENT_USER" ] || [ "$CURRENT_USER" = "root" ]; then
    CURRENT_USER="$(who am i | awk '{print $1}')"
    CURRENT_GROUP="$(id -gn "$CURRENT_USER" 2>/dev/null || echo "$CURRENT_USER")"
  fi
  
  # Run all the setup steps in sequence
  check_container
  
  # Create local unbound directory
  echo -e "${BLUE}${GEAR} Creating local Unbound configuration directory...${NC}"
  mkdir -p "${HOST_UNBOUND_DIR}"
  
  # Create custom.conf file
  echo -e "${BLUE}${GEAR} Creating custom Unbound configuration file...${NC}"
  if [ -f "${HOST_UNBOUND_DIR}/custom.conf" ]; then
    echo -e "${YELLOW}${WARNING} Custom Unbound configuration file already exists.${NC}"
  else
    cat > "${HOST_UNBOUND_DIR}/custom.conf" <<EOF
# ======================================================
# Custom Unbound Configuration for Docker Named Volumes
# ======================================================
# Add your custom Unbound configurations here
# They will be loaded after the default configurations

server:
    # DNSSEC validation
    auto-trust-anchor-file: "/var/lib/unbound/root.key"
    val-clean-additional: yes
    
    # DNSSEC verification options
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-referral-path: yes
    
    # Security improvements
    use-caps-for-id: yes
    
    # Performance enhancements
    prefetch: yes
    prefetch-key: yes
    qname-minimisation: yes
    
    # Cache improvements
    cache-min-ttl: 300
    cache-max-ttl: 86400
    
    # IPv6 options
    do-ip6: no
EOF
    echo -e "${GREEN}${CHECK} Created custom configuration file with DNSSEC settings.${NC}"
  fi

  # Change ownership of unbound directory to current user
  chown -R "${CURRENT_USER}:${CURRENT_GROUP}" "${HOST_UNBOUND_DIR}" || {
    echo -e "${YELLOW}${WARNING} Could not change ownership of ${HOST_UNBOUND_DIR}.${NC}"
    echo -e "${YELLOW}Try running the script with sudo.${NC}"
  }

  # Update the docker-compose file
  find_compose_file
  modify_docker_compose
  
  # Restart the container if requested and if modify_docker_compose was successful
  if grep -q "${HOST_UNBOUND_DIR}:/etc/unbound/custom.conf.d:rw" "${COMPOSE_FILE}"; then
    echo -e "${YELLOW}❓ Do you want to restart the container to apply changes? [Y/n]${NC}"
    read -r RESTART_CONTAINER
    if [[ "$RESTART_CONTAINER" =~ ^[Nn]$ ]]; then
      echo -e "${YELLOW}${WARNING} Container not restarted. Changes will apply after the next restart.${NC}"
    else
      restart_container
    fi

    # Print summary
    print_custom_summary
  else
    echo -e "${YELLOW}${WARNING} Please update your docker-compose.yaml manually and run this script again.${NC}"
  fi
}

# Run the main function
main
