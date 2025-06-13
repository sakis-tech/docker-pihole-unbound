#!/usr/bin/env bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Pi-hole + Unbound Docker Installer${NC}"

dir_setup() {
  echo -e "${YELLOW}Creating configuration directories...${NC}"
  mkdir -p config/unbound
}

download_unbound_references() {
  echo -e "${YELLOW}Fetching root hints...${NC}"
  curl -sfSL https://www.internic.net/domain/named.root -o config/unbound/root.hints

  echo -e "${YELLOW}Initializing DNSSEC anchor (root.key)...${NC}"
  unbound-anchor -a config/unbound/root.key
}

generate_unbound_conf() {
  echo -e "${YELLOW}Generating default unbound.conf...${NC}"
  cat > config/unbound/unbound.conf <<'EOF'
server:
  verbosity: 1
  interface: 0.0.0.0
  port: 5335
  num-threads: 2
  do-ip4: yes
  do-udp: yes
  do-tcp: yes
  root-hints: "/etc/unbound/root.hints"
  auto-trust-anchor-file: "/etc/unbound/root.key"
EOF

  echo -e "${YELLOW}Opening unbound.conf for review...${NC}"
  ${EDITOR:-vi} config/unbound/unbound.conf
}

prompt_env() {
  echo -e "${YELLOW}Configuring environment variables (.env)...${NC}"
  read -p "Hostname for container: " HOSTNAME
  read -p "Domain name (optional): " DOMAIN_NAME
  read -p "Time Zone (e.g. Europe/Berlin): " TZ_ZONE
  read -p "Pi-hole Web Admin Password: " WEBPASSWORD
  read -p "Pi-hole Web UI Theme [default-light|default-dark|slate|...] (optional): " WEBTHEME
  read -p "Pi-hole Web UI Port (default 80): " PIHOLE_WEBPORT

  cat > .env <<EOF
HOSTNAME=${HOSTNAME}
DOMAIN_NAME=${DOMAIN_NAME}
TZ=${TZ_ZONE}
WEBPASSWORD=${WEBPASSWORD}
WEBTHEME=${WEBTHEME}
PIHOLE_WEBPORT=${PIHOLE_WEBPORT:-80}
EOF
}

generate_docker_compose() {
  echo -e "${YELLOW}Writing docker-compose.yaml...${NC}"
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
      - TZ=${TZ:-UTC}
      - FTLCONF_webserver_api_password=${WEBPASSWORD}
      - FTLCONF_webserver_interface_theme=${WEBTHEME:-default-light}
      - FTLCONF_dns_upstreams=127.0.0.1#5335
      - FTLCONF_dns_listeningMode=all
      - FTLCONF_webserver_port=${PIHOLE_WEBPORT}
    volumes:
      - etc_pihole-unbound:/etc/pihole:rw
      - etc_pihole_dnsmasq-unbound:/etc/dnsmasq.d:rw
    restart: unless-stopped

volumes:
  etc_pihole-unbound:
  etc_pihole_dnsmasq-unbound:
EOF
}

main() {
  dir_setup
  download_unbound_references
  generate_unbound_conf
  prompt_env
  generate_docker_compose

  echo -e "${GREEN}Installation script completed!${NC}"
  echo "Run 'docker-compose up -d' to start Pi-hole with Unbound."
}

main
