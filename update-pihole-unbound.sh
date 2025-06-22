#!/usr/bin/env bash
#
# Update script for Pi-hole with Unbound DNS resolver in Docker
# 
# Description: Updates Pi-hole and Unbound Docker containers to the latest version
# Version: 1.2.0 (2025-06-15)
# 
# Usage: ./update-pihole-unbound.sh
#

set -euo pipefail

# ======================================================
# VARIABLES
# ======================================================

# Color codes for pretty output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Icons for better visual feedback
CHECK="✓"
CROSS="✗"
ARROW="▶"
RESTART="🔄"
WARNING="⚠️"
GEAR="⚙️"
WRITE="📝"
START="🚀"
SEARCH="🔍"
SUCCESS="🎉"
INFO="ℹ️"
BACKUP="💾"
VERSION="📊"

# Compose command will be set in check_compose() function
COMPOSE_CMD=""

# Repository directory name (should match install script)
REPO_DIR="docker-pihole-unbound"

# Variables for file paths
ENV_FILE=".env"
COMPOSE_FILE="docker-compose.yaml"

# Temporary files for version tracking
TMP_VERSION_DIR="/tmp/pihole_update"
OLD_VERSIONS_FILE="${TMP_VERSION_DIR}/old_versions.txt"
NEW_VERSIONS_FILE="${TMP_VERSION_DIR}/new_versions.txt"

#######################################
# Find installation directory if needed
# Globals:
#   REPO_DIR, COMPOSE_FILE, ENV_FILE, RED, CROSS, NC
# Arguments:
#   None
# Returns:
#   None, but changes directory if needed
#######################################
find_install_dir() {
  echo -e "${BLUE}${SEARCH} Searching for installation directory...${NC}"
  
  # Check if we're already in the right directory
  if [[ -f "$COMPOSE_FILE" ]]; then
    echo -e "${GREEN}${CHECK} Installation directory found: $(pwd)${NC}"
    return 0
  fi
  
  # If not in correct directory but it exists, move to it
  if [[ -d "$REPO_DIR" ]]; then
    cd "$REPO_DIR"
    if [[ -f "$COMPOSE_FILE" ]]; then
      echo -e "${GREEN}${CHECK} Switched to installation directory: $(pwd)${NC}"
      return 0
    fi
  fi
  
  # If we still can't find the compose file, exit
  echo -e "${RED}${CROSS} $COMPOSE_FILE not found. Please make sure you are in the project directory or '$REPO_DIR' exists.${NC}"
  exit 1
}

#######################################
# Load environment variables from .env file
# Globals:
#   ENV_FILE, RED, CROSS, GREEN, CHECK, NC
# Arguments:
#   None
#######################################
load_env_vars() {
  if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}${CROSS} $ENV_FILE file not found. Please make sure you are in the project directory.${NC}"
    exit 1
  fi
  
  echo -e "${GREEN}${CHECK} Loading environment variables from $ENV_FILE...${NC}"
  # shellcheck disable=SC1091
  source <(grep -E '^[A-Z0-9_]+=' "$ENV_FILE")
}

#######################################
# Print header and script information
# Globals:
#   BLUE, GREEN, YELLOW, NC
# Arguments:
#   None
#######################################
print_header() {
  clear
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${BLUE}        Pi-hole + Unbound Update Script v1.2.0               ${NC}"
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  
  echo -e "${BLUE}${ARROW} This script will automatically:${NC}"
  echo -e "${YELLOW}   ${RESTART} Download the latest Docker images${NC}"
  echo -e "${YELLOW}   ${START} Restart the containers with updated images${NC}"
  echo -e "${YELLOW}   ${SEARCH} Test DNS resolution functionality${NC}"
  echo -e "${YELLOW}   ${VERSION} Show version and configuration details${NC}"
  echo -e "${YELLOW}   ${WRITE} Show optional container logs${NC}"
  echo
  echo -e "${GREEN}Press [Enter] to continue or Ctrl+C to cancel...${NC}"
  read -r _
}

#######################################
# Check if Docker Compose is installed
# Globals:
#   COMPOSE_CMD, GREEN, RED, CROSS, CHECK, NC
# Arguments:
#   None
#######################################
check_compose() {
  echo -e "${BLUE}${ARROW} Checking Docker Compose installation...${NC}"
  
  if command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
    echo -e "${GREEN}${CHECK} Docker Compose (classic) found${NC}"
  elif docker compose version &>/dev/null; then
    COMPOSE_CMD="docker compose"
    echo -e "${GREEN}${CHECK} Docker Compose Plugin found${NC}"
  else
    echo -e "${RED}${CROSS} Docker Compose is not installed. Please run the installation script first.${NC}"
    exit 1
  fi
}

#######################################
# Update and restart containers
# Globals:
#   COMPOSE_CMD, GREEN, YELLOW, BLUE, RESTART, START, CHECK, NC
# Arguments:
#   None
#######################################
#######################################
# Check and store current versions before update
# Globals:
#   COMPOSE_CMD, BLUE, YELLOW, ARROW, NC, TMP_VERSION_DIR, OLD_VERSIONS_FILE
# Arguments:
#   None
#######################################
check_current_versions() {
  echo -e "${BLUE}${ARROW} Checking current versions...${NC}"
  
  # Create temp directory if it doesn't exist
  if ! mkdir -p "${TMP_VERSION_DIR}" 2>/dev/null; then
    echo -e "${YELLOW}${WARNING} Could not create temp directory, using current directory${NC}"
    TMP_VERSION_DIR="."
    OLD_VERSIONS_FILE="./old_versions.tmp"
    NEW_VERSIONS_FILE="./new_versions.tmp"
  fi
  
  # Check if containers are running
  if ! $COMPOSE_CMD ps | grep -q "pihole-unbound.*Up"; then
    echo -e "${YELLOW}${WARNING} Containers not running, can't check current versions${NC}"
    echo "export PIHOLE_VERSION=\"unknown\"" > "$OLD_VERSIONS_FILE"
    echo "export UNBOUND_VERSION=\"unknown\"" >> "$OLD_VERSIONS_FILE"
    return 0
  fi
  
  # Get current versions with error handling
  echo -e "${YELLOW}• Checking Pi-hole version...${NC}"
  # Get all Pi-hole component versions
  PIHOLE_CORE=$($COMPOSE_CMD exec -T pihole-unbound pihole -v 2>/dev/null | grep -o 'Core version is v[0-9]\+\.[0-9]\+\.[0-9]\+' 2>/dev/null | sed 's/Core version is v//' || echo "unknown")
  PIHOLE_WEB=$($COMPOSE_CMD exec -T pihole-unbound pihole -v 2>/dev/null | grep -o 'Web version is v[0-9]\+\.[0-9]\+\.[0-9]\+' 2>/dev/null | sed 's/Web version is v//' || echo "unknown")
  PIHOLE_FTL=$($COMPOSE_CMD exec -T pihole-unbound pihole -v 2>/dev/null | grep -o 'FTL version is v[0-9]\+\.[0-9]\+\.[0-9]\+' 2>/dev/null | sed 's/FTL version is v//' || echo "unknown")
  
  # Use Core version as the main Pi-hole version
  PIHOLE_VERSION="$PIHOLE_CORE"
  echo -e "${YELLOW}• Checking Unbound version...${NC}"
  UNBOUND_VERSION=$($COMPOSE_CMD exec -T pihole-unbound unbound -V 2>/dev/null | head -n1 | grep -oP 'Version \K[0-9.]+' 2>/dev/null || echo "unknown")
  
  # Store versions in temp file - properly quoted for sourcing
  echo "export PIHOLE_VERSION=\"$PIHOLE_VERSION\"" > "$OLD_VERSIONS_FILE"
  echo "export UNBOUND_VERSION=\"$UNBOUND_VERSION\"" >> "$OLD_VERSIONS_FILE"
  
  echo -e "${GREEN}${CHECK} Current versions recorded${NC}"
}

update_containers() {
  echo -e "${BLUE}${ARROW} Starting update...${NC}"
  
  echo -e "${YELLOW}${RESTART} Downloading latest images...${NC}"
  $COMPOSE_CMD pull
  
  echo -e "${YELLOW}${START} Restarting containers...${NC}"
  $COMPOSE_CMD up -d
  
  echo -e "${GREEN}${CHECK} Containers successfully updated and restarted${NC}"
}

#######################################
# Show status and configuration after update
# Globals:
#   BLUE, GREEN, YELLOW, NC, PIHOLE_IP, PIHOLE_WEBPORT, DOMAIN_NAME
#   WEBTHEME, HOSTNAME, TZ, COMPOSE_CMD, SUCCESS
# Arguments:
#   None
#######################################
#######################################
# Check new versions after update
# Globals:
#   COMPOSE_CMD, BLUE, YELLOW, ARROW, NC, TMP_VERSION_DIR, NEW_VERSIONS_FILE
# Arguments:
#   None
#######################################
check_new_versions() {
  echo -e "${BLUE}${ARROW} Checking updated versions...${NC}"
  
  # Wait a moment for containers to be fully started
  sleep 5
  
  # Check if containers are running
  if ! $COMPOSE_CMD ps | grep -q "pihole-unbound.*Up"; then
    echo -e "${YELLOW}${WARNING} Containers not running, can't check updated versions${NC}"
    echo "export PIHOLE_VERSION=\"unknown\"" > "$NEW_VERSIONS_FILE"
    echo "export UNBOUND_VERSION=\"unknown\"" >> "$NEW_VERSIONS_FILE"
    return 0
  fi
  
  # Get new versions with error handling
  # Get all Pi-hole component versions
  PIHOLE_CORE=$($COMPOSE_CMD exec -T pihole-unbound pihole -v 2>/dev/null | grep -o 'Core version is v[0-9]\+\.[0-9]\+\.[0-9]\+' 2>/dev/null | sed 's/Core version is v//' || echo "unknown")
  PIHOLE_WEB=$($COMPOSE_CMD exec -T pihole-unbound pihole -v 2>/dev/null | grep -o 'Web version is v[0-9]\+\.[0-9]\+\.[0-9]\+' 2>/dev/null | sed 's/Web version is v//' || echo "unknown")
  PIHOLE_FTL=$($COMPOSE_CMD exec -T pihole-unbound pihole -v 2>/dev/null | grep -o 'FTL version is v[0-9]\+\.[0-9]\+\.[0-9]\+' 2>/dev/null | sed 's/FTL version is v//' || echo "unknown")
  
  # Use Core version as the main Pi-hole version
  PIHOLE_VERSION="$PIHOLE_CORE"
  UNBOUND_VERSION=$($COMPOSE_CMD exec -T pihole-unbound unbound -V 2>/dev/null | head -n1 | grep -oP 'Version \K[0-9.]+' 2>/dev/null || echo "unknown")
  
  # Store versions in temp file - properly quoted for sourcing
  echo "export PIHOLE_VERSION=\"$PIHOLE_VERSION\"" > "$NEW_VERSIONS_FILE"
  echo "export UNBOUND_VERSION=\"$UNBOUND_VERSION\"" >> "$NEW_VERSIONS_FILE"
  
  echo -e "${GREEN}${CHECK} Updated versions recorded${NC}"
}

#######################################
# Compare old and new versions and display changes
# Globals:
#   BLUE, YELLOW, GREEN, RED, ARROW, NC, OLD_VERSIONS_FILE, NEW_VERSIONS_FILE
# Arguments:
#   None
#######################################
show_version_changes() {
  echo -e "${BLUE}${ARROW} Checking version changes...${NC}"
  
  # Initialize variables with defaults
  OLD_PIHOLE_VERSION="unknown"
  OLD_UNBOUND_VERSION="unknown"
  NEW_PIHOLE_VERSION="unknown"
  NEW_UNBOUND_VERSION="unknown"
  
  # Load old versions with error handling
  if [[ -f "$OLD_VERSIONS_FILE" ]]; then
    # Verify file isn't empty
    if [[ -s "$OLD_VERSIONS_FILE" ]]; then
      echo -e "${YELLOW}• Loading previous version data...${NC}"
      # shellcheck disable=SC1090
      if source "$OLD_VERSIONS_FILE" 2>/dev/null; then
        OLD_PIHOLE_VERSION="$PIHOLE_VERSION"
        OLD_UNBOUND_VERSION="$UNBOUND_VERSION"
      else
        echo -e "${YELLOW}${WARNING} Error loading old version data${NC}"
      fi
    else
      echo -e "${YELLOW}${WARNING} Version data file is empty${NC}"
    fi
  else
    echo -e "${YELLOW}${WARNING} Previous version data not found${NC}"
  fi
  
  # Load new versions with error handling
  if [[ -f "$NEW_VERSIONS_FILE" ]]; then
    # Verify file isn't empty
    if [[ -s "$NEW_VERSIONS_FILE" ]]; then
      echo -e "${YELLOW}• Loading updated version data...${NC}"
      # shellcheck disable=SC1090
      if source "$NEW_VERSIONS_FILE" 2>/dev/null; then
        NEW_PIHOLE_VERSION="$PIHOLE_VERSION"
        NEW_UNBOUND_VERSION="$UNBOUND_VERSION"
      else
        echo -e "${YELLOW}${WARNING} Error loading new version data${NC}"
        # Try to get current versions directly
        NEW_PIHOLE_CORE=$($COMPOSE_CMD exec -T pihole-unbound pihole -v 2>/dev/null | grep -o 'Core version is v[0-9]\+\.[0-9]\+\.[0-9]\+' 2>/dev/null | sed 's/Core version is v//' || echo "unknown")
        NEW_PIHOLE_VERSION="$NEW_PIHOLE_CORE"
        NEW_UNBOUND_VERSION=$($COMPOSE_CMD exec -T pihole-unbound unbound -V 2>/dev/null | head -n1 | grep -oP 'Version \K[0-9.]+' 2>/dev/null || echo "unknown")
      fi
    else
      echo -e "${YELLOW}${WARNING} Updated version data file is empty${NC}"
    fi
  else
    echo -e "${YELLOW}${WARNING} Updated version data not found${NC}"
    # Try to get current versions directly
    NEW_PIHOLE_CORE=$($COMPOSE_CMD exec -T pihole-unbound pihole -v 2>/dev/null | grep -o 'Core version is v[0-9]\+\.[0-9]\+\.[0-9]\+' 2>/dev/null | sed 's/Core version is v//' || echo "unknown")
    NEW_PIHOLE_VERSION="$NEW_PIHOLE_CORE"
    NEW_UNBOUND_VERSION=$($COMPOSE_CMD exec -T pihole-unbound unbound -V 2>/dev/null | head -n1 | grep -oP 'Version \K[0-9.]+' 2>/dev/null || echo "unknown")
  fi
  
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${BLUE}${GEAR} Version comparison:                                      ${NC}"
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  
  # Show Pi-hole version comparison
  echo -n -e "${YELLOW}• Pi-hole:    ${NC}"
  if [[ "$OLD_PIHOLE_VERSION" == "unknown" || "$NEW_PIHOLE_VERSION" == "unknown" ]]; then
    echo -e "${GREEN}v$NEW_PIHOLE_VERSION${NC}"
  elif [[ "$OLD_PIHOLE_VERSION" != "$NEW_PIHOLE_VERSION" ]]; then
    echo -e "${RED}v$OLD_PIHOLE_VERSION${NC} → ${GREEN}v$NEW_PIHOLE_VERSION${NC}"
  else
    echo -e "${GREEN}v$NEW_PIHOLE_VERSION${NC} (no change)"
  fi
  
  # Show Unbound version comparison
  echo -n -e "${YELLOW}• Unbound:    ${NC}"
  
  # Trim any whitespace from version strings
  OLD_UNBOUND_VERSION_CLEAN=$(echo "$OLD_UNBOUND_VERSION" | tr -d ' \t\n\r')
  NEW_UNBOUND_VERSION_CLEAN=$(echo "$NEW_UNBOUND_VERSION" | tr -d ' \t\n\r')
  
  # Debug-Ausgabe für Debugging entfernen oder auskommentieren
  # echo "DEBUG: Old='$OLD_UNBOUND_VERSION_CLEAN', New='$NEW_UNBOUND_VERSION_CLEAN'" > /dev/stderr
  
  if [[ "$OLD_UNBOUND_VERSION_CLEAN" == "unknown" && "$NEW_UNBOUND_VERSION_CLEAN" != "unknown" ]]; then
    # Wenn nur die neue Version bekannt ist, zeige nur diese an
    echo -e "${GREEN}v$NEW_UNBOUND_VERSION_CLEAN${NC}"
  elif [[ "$OLD_UNBOUND_VERSION_CLEAN" != "unknown" && "$NEW_UNBOUND_VERSION_CLEAN" == "unknown" ]]; then
    # Wenn nur die alte Version bekannt ist, zeige diese mit Warnung
    echo -e "${RED}v$OLD_UNBOUND_VERSION_CLEAN${NC} → ${YELLOW}unknown${NC}"
  elif [[ "$OLD_UNBOUND_VERSION_CLEAN" == "unknown" && "$NEW_UNBOUND_VERSION_CLEAN" == "unknown" ]]; then
    # Wenn beide unbekannt sind
    echo -e "${YELLOW}unknown${NC}"
  elif [[ "$OLD_UNBOUND_VERSION_CLEAN" != "$NEW_UNBOUND_VERSION_CLEAN" ]]; then
    # Wenn sich die Version geändert hat
    echo -e "${RED}v$OLD_UNBOUND_VERSION_CLEAN${NC} → ${GREEN}v$NEW_UNBOUND_VERSION_CLEAN${NC}"
  else
    # Wenn keine Änderung
    echo -e "${GREEN}v$NEW_UNBOUND_VERSION_CLEAN${NC} (no change)"
  fi
  
  # Clean up temp files
  if [[ "$TMP_VERSION_DIR" != "." ]]; then
    rm -f "$OLD_VERSIONS_FILE" "$NEW_VERSIONS_FILE" 2>/dev/null
  fi
}

#######################################
#######################################
# Test DNS resolution after update
# Globals:
#   BLUE, GREEN, RED, CROSS, CHECK, ARROW, NC, PIHOLE_IP
# Arguments:
#   None
#######################################
test_dns_resolution() {
  echo -e "${BLUE}${ARROW} Testing DNS resolution...${NC}"
  
  # Ask if user wants to test DNS resolution
  echo -e "${BLUE}${ARROW} Do you want to test DNS resolution after update? (y/N)${NC}"
  read -r TEST_DNS
  
  if [[ ! "$TEST_DNS" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}${WARNING} DNS testing skipped by user request${NC}"
    return 0
  fi
  
  # First test basic network connectivity
  echo -e "${YELLOW}• Testing basic network connectivity...${NC}"
  if ping -c 1 -W 2 1.1.1.1 > /dev/null 2>&1; then
    echo -e "${GREEN}${CHECK} Basic network connectivity OK${NC}"
  else
    echo -e "${RED}${CROSS} Network connectivity failed${NC}"
    echo -e "${YELLOW}${WARNING} Cannot reach internet, DNS tests may not be reliable${NC}"
  fi
  
  # Check if dig command is available
  local DNS_TOOL=""
  if command -v dig &>/dev/null; then
    DNS_TOOL="dig"
    echo -e "${GREEN}${CHECK} Using dig for DNS tests${NC}"
  elif command -v nslookup &>/dev/null; then
    DNS_TOOL="nslookup"
    echo -e "${GREEN}${CHECK} Using nslookup for DNS tests${NC}"
  else
    echo -e "${YELLOW}${WARNING} Neither 'dig' nor 'nslookup' found.${NC}"
    echo -e "${BLUE}${ARROW} Would you like to install dnsutils package to enable DNS testing? (y/n)${NC}"
    read -r INSTALL_DNSUTILS
    
    if [[ "$INSTALL_DNSUTILS" =~ ^[Yy]$ ]]; then
      echo -e "${YELLOW}• Installing dnsutils package...${NC}"
      if [[ -f /etc/debian_version ]]; then
        sudo apt-get update && sudo apt-get install -y dnsutils
      elif [[ -f /etc/redhat-release ]]; then
        sudo yum install -y bind-utils
      else
        echo -e "${RED}${CROSS} Could not determine your distribution. Please install the DNS tools manually:${NC}"
        echo -e "${YELLOW}• Debian/Ubuntu: sudo apt-get install dnsutils${NC}"
        echo -e "${YELLOW}• CentOS/Fedora: sudo yum install bind-utils${NC}"
      fi
      
      # Check if installation was successful
      if command -v dig &>/dev/null; then
        DNS_TOOL="dig"
        echo -e "${GREEN}${CHECK} dnsutils successfully installed, using dig for DNS tests${NC}"
      elif command -v nslookup &>/dev/null; then
        DNS_TOOL="nslookup"
        echo -e "${GREEN}${CHECK} dnsutils successfully installed, using nslookup for DNS tests${NC}"
      else
        echo -e "${RED}${CROSS} Installation failed or tools not in path. Trying container-internal tests only${NC}"
      fi
    else
      echo -e "${YELLOW}• Trying container-internal tests only${NC}"
    fi
  fi
  
  # Check if Pi-hole IP is defined
  if [[ -z "$PIHOLE_IP" ]]; then
    echo -e "${YELLOW}${WARNING} Pi-hole IP not defined in environment variables, using localhost${NC}"
    local DNS_SERVER="127.0.0.1"
  else
    local DNS_SERVER="$PIHOLE_IP"
  fi
  
  # Test domains
  local TEST_DOMAINS=("google.com" "github.com" "cloudflare.com")
  local EXTERNAL_SUCCESS=false
  local INTERNAL_SUCCESS=false
  local TIMEOUT=3  # Increased timeout for more reliability
  
  echo -e "${YELLOW}• Testing DNS resolution against server: ${DNS_SERVER}${NC}"
  
  # Test each domain with both external and internal methods
  for domain in "${TEST_DOMAINS[@]}"; do
    echo -e "${YELLOW}• Testing domain: ${domain}${NC}"
    
    # External test from host if we have a DNS tool
    if [[ -n "$DNS_TOOL" ]]; then
      echo -n -e "  ${YELLOW}• External test:${NC} "
      if [[ "$DNS_TOOL" == "dig" ]]; then
        if timeout $TIMEOUT dig +short "@${DNS_SERVER}" "$domain" > /dev/null 2>&1; then
          echo -e "${GREEN}${CHECK} Success${NC}"
          EXTERNAL_SUCCESS=true
        else
          echo -e "${BLUE}• Not available${NC} - ${GREEN}${CHECK}expected with macvlan${NC}"  
        fi
      elif [[ "$DNS_TOOL" == "nslookup" ]]; then
        if timeout $TIMEOUT nslookup "$domain" "$DNS_SERVER" > /dev/null 2>&1; then
          echo -e "${GREEN}${CHECK} Success${NC}"
          EXTERNAL_SUCCESS=true
        else
          echo -e "${BLUE}• Not available${NC} - ${GREEN}${CHECK}expected with macvlan${NC}"
        fi
      fi
    fi
    
    # Always try internal test within container
    echo -n -e "  ${YELLOW}• Internal container test:${NC} "
    if $COMPOSE_CMD exec -T pihole-unbound nslookup "$domain" localhost > /dev/null 2>&1; then
      echo -e "${GREEN}${CHECK} Success${NC}"
      INTERNAL_SUCCESS=true
    else
      echo -e "${RED}${CROSS} Failed${NC}"
    fi
  done
  
  # Overall diagnostic result
  echo
  if [[ "$EXTERNAL_SUCCESS" == "true" && "$INTERNAL_SUCCESS" == "true" ]]; then
    echo -e "${GREEN}${CHECK} DNS resolution working correctly (both external and internal)${NC}"
    return 0
  elif [[ "$INTERNAL_SUCCESS" == "true" ]]; then
    echo -e "${GREEN}${CHECK} DNS resolution working correctly inside container${NC}"
    echo -e "${YELLOW}• External tests not available${NC} ${GREEN}${CHECK}(normal with macvlan configuration)${NC}"
    echo -e "${GREEN}${CHECK} Other devices on your network can use Pi-hole for DNS${NC}"
    echo -e "${YELLOW}${INFO} Tip: For host DNS resolution, use router as described in README.md${NC}"
  else
    echo -e "${RED}${CROSS} DNS resolution not working${NC}"
    echo -e "${YELLOW}${ARROW} Troubleshooting tips:${NC}"
    echo -e "${YELLOW}• Make sure Pi-hole container is running: docker ps | grep pihole${NC}"
    echo -e "${YELLOW}• Check if DNS service is running in container: ${COMPOSE_CMD} exec pihole-unbound netstat -tuln | grep 53${NC}"
    echo -e "${YELLOW}• Try restarting the container: ${COMPOSE_CMD} restart pihole-unbound${NC}"
    echo -e "${YELLOW}• Check logs for errors: ${COMPOSE_CMD} logs pihole-unbound${NC}"
  fi
}

show_status() {
  echo
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${BLUE}${SUCCESS} Update completed!                                      ${NC}"
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  
  # Show version changes
  show_version_changes
  
  # Configuration summary
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${BLUE}${ARROW} Current configuration:${NC}"
  echo -e "${YELLOW}• Pi-hole IP:     ${NC}${GREEN}${PIHOLE_IP}${NC}"
  echo -e "${YELLOW}• Web Port:       ${NC}${GREEN}${PIHOLE_WEBPORT}${NC}"
  echo -e "${YELLOW}• Domain:         ${NC}${GREEN}${DOMAIN_NAME}${NC}"
  echo -e "${YELLOW}• Theme:          ${NC}${GREEN}${WEBTHEME}${NC}"
  echo -e "${YELLOW}• Hostname:       ${NC}${GREEN}${HOSTNAME}${NC}"
  echo -e "${YELLOW}• Timezone:       ${NC}${GREEN}${TZ}${NC}"
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  
  # Test DNS resolution
  test_dns_resolution
  
  # Ask for logs
  echo
  echo -e "${BLUE}${ARROW} Would you like to view the logs? (y/N)${NC}"
  read -r SHOW_LOGS
  if [[ "$SHOW_LOGS" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
    echo -e "${BLUE}${WRITE} Latest logs:                                             ${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
    $COMPOSE_CMD logs --tail 20
  fi
  
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
  echo -e "${BLUE}${CHECK} Pi-hole + Unbound have been successfully updated!${NC}"
  echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
}

#######################################
# Main function
# Arguments:
#   None
#######################################
main() {
  print_header
  find_install_dir
  load_env_vars
  check_compose
  check_current_versions
  update_containers
  check_new_versions
  show_status
}

# Execute main function
main "$@"
