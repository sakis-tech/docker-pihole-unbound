#!/usr/bin/env bash
set -euo pipefail

##### Farben #####
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

REPO_URL="https://github.com/sakis-tech/docker-pihole-unbound.git"
WORKDIR="docker-pihole-unbound"

##### OS-Erkennung #####
detect_os(){
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    case "$ID" in
      ubuntu|debian)      PKG_MGR="apt-get"; INSTALL="sudo apt-get install -y"; UPDATE="sudo apt-get update";;
      fedora|centos|rhel) PKG_MGR="yum";     INSTALL="sudo yum install -y";    UPDATE="";;
      alpine)             PKG_MGR="apk";     INSTALL="sudo apk add";          UPDATE="";;
      *)                  PKG_MGR="";;
    esac
  fi
}

##### Helfer #####
command_exists(){ command -v "$1" &>/dev/null; }
print_step(){ echo -e "\n${CYAN}▶ $1${NC}"; }
header(){
  clear
  echo -e "${BLUE}==============================================${NC}"
  echo -e "     ${CYAN}Pi-hole + Unbound Auto‑Installer${NC}"
  echo -e "${BLUE}==============================================${NC}"
}
intro(){
  header
  echo -e "${YELLOW}Dieses Skript installiert automatisch:${NC}"
  echo "- Docker & Docker Compose"
  echo "- Git & Curl"
  echo "- Klont das Repo"
  echo "- Erstellt .env und docker-compose.yaml"
  echo "- Startet Pi-hole + Unbound im Docker-Host‑Netz"
  echo
  read -rp "→ Drücke [Enter] um zu starten…" _
}

##### 1) Voraussetzungen installieren #####
install_prereqs(){
  print_step "Prüfe Git & Curl…"
  local need_git=false need_curl=false
  command_exists git  || need_git=true
  command_exists curl || need_curl=true

  if $need_git || $need_curl; then
    read -rp "→ Git/Curl fehlen. Installieren? [y/N]: " ans; ans=${ans,,}
    if [[ "$ans" =~ ^(y|yes)$ ]]; then
      if [[ -n "$PKG_MGR" ]]; then
        $UPDATE
        $INSTALL git curl
      else
        echo -e "${RED}OS nicht unterstützt – installiere git & curl manuell.${NC}"
        exit 1
      fi
    else
      echo -e "${RED}Abbruch, Git und Curl werden benötigt.${NC}"
      exit 1
    fi
  else
    echo -e "${GREEN}Git & Curl sind vorhanden.${NC}"
  fi

  print_step "Prüfe Docker & Docker Compose…"
  local need_docker=false need_compose=false

  if command_exists docker; then
    echo -e "${GREEN}$(docker --version)${NC}"
  else
    echo -e "${RED}Docker fehlt${NC}"
    need_docker=true
  fi

  if docker-compose version &>/dev/null; then
    echo -e "${GREEN}$(docker-compose version)${NC}"
  elif docker compose version &>/dev/null; then
    echo -e "${GREEN}$(docker compose version)${NC}"
  else
    echo -e "${RED}Docker Compose fehlt${NC}"
    need_compose=true
  fi

  if ! $need_docker && ! $need_compose; then
    echo -e "${GREEN}Docker & Compose sind vorhanden.${NC}"
    return
  fi

  read -rp "→ Fehlende Tools installieren? [y/N]: " ans; ans=${ans,,}
  if [[ "$ans" =~ ^(y|yes)$ ]]; then
    if $need_docker; then
      print_step "Installiere Docker…"
      curl -fsSL https://get.docker.com -o get-docker.sh
      sudo sh get-docker.sh
    fi
    if $need_compose; then
      print_step "Installiere Docker Compose…"
      case "$PKG_MGR" in
        apt-get)
          sudo apt-get update
          sudo apt-get install -y docker-compose-plugin
          sudo ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
          ;;
        yum)
          sudo yum install -y python3-pip
          sudo pip3 install docker-compose
          ;;
        apk)
          sudo apk add docker-compose
          ;;
      esac
    fi
  else
    echo -e "${RED}Abbruch. Fehlende Tools müssen installiert werden.${NC}"
    exit 1
  fi
}

##### 2) Docker‑Gruppe #####
configure_docker_group(){
  print_step "Prüfe docker‑Gruppe für $USER…"
  if id -nG "$USER" | grep -qw docker; then
    echo -e "${GREEN}$USER ist bereits in docker‑Gruppe.${NC}"
  else
    read -rp "→ $USER zur docker‑Gruppe hinzufügen? [y/N]: " ans; ans=${ans,,}
    if [[ "$ans" =~ ^(y|yes)$ ]]; then
      sudo usermod -aG docker "$USER"
      echo -e "${GREEN}Erledigt – bitte abmelden und neu anmelden.${NC}"
    else
      echo -e "${YELLOW}Übersprungen.${NC}"
    fi
  fi
}

##### 3) Repo klonen #####
clone_repo(){
  print_step "Klonen des Repositories…"
  if [[ -d "$WORKDIR" ]]; then
    echo -e "${GREEN}$WORKDIR existiert – übersprungen.${NC}"
  else
    git clone "$REPO_URL"
  fi
  cd "$WORKDIR"
}

##### 4) .env generieren #####
generate_env(){
  print_step "Erstelle .env…"
  # Beispielwerte
  local example_host="pi-hole"
  local example_domain="lan"
  local example_tz="Europe/Berlin"
  local example_pw="admin"
  local example_theme="default-light"
  local example_port="80"

  echo -e "Beispielwerte:"
  echo -e "  HOSTNAME=${example_host}"
  echo -e "  DOMAIN_NAME=${example_domain}"
  echo -e "  TZ=${example_tz}"
  echo -e "  WEBPASSWORD=${example_pw}"
  echo -e "  WEBTHEME=${example_theme}"
  echo -e "  PIHOLE_WEBPORT=${example_port}"
  read -rp "→ Beispielwerte verwenden? [Y/n]: " use_example
  use_example=${use_example,,}

  if [[ -z "$use_example" || "$use_example" == "y" || "$use_example" == "yes" ]]; then
    HOSTNAME="$example_host"
    DOMAIN_NAME="$example_domain"
    TZ_ZONE="$example_tz"
    WEBPASSWORD="$example_pw"
    WEBTHEME="$example_theme"
    PIHOLE_WEBPORT="$example_port"
  else
    read -rp "Hostname [${example_host}]: " HOSTNAME
    HOSTNAME=${HOSTNAME:-$example_host}
    read -rp "Domain (optional) [${example_domain}]: " DOMAIN_NAME
    DOMAIN_NAME=${DOMAIN_NAME:-$example_domain}
    read -rp "Zeitzone [${example_tz}]: " TZ_ZONE
    TZ_ZONE=${TZ_ZONE:-$example_tz}
    read -rp "Web‑Admin Passwort [${example_pw}]: " WEBPASSWORD
    WEBPASSWORD=${WEBPASSWORD:-$example_pw}
    read -rp "Theme [${example_theme}]: " WEBTHEME
    WEBTHEME=${WEBTHEME:-$example_theme}
    read -rp "Web UI Port [${example_port}]: " PIHOLE_WEBPORT
    PIHOLE_WEBPORT=${PIHOLE_WEBPORT:-$example_port}
  fi

  cat > .env <<EOF
HOSTNAME=${HOSTNAME}
DOMAIN_NAME=${DOMAIN_NAME}
TZ=${TZ_ZONE}
WEBPASSWORD=${WEBPASSWORD}
WEBTHEME=${WEBTHEME}
PIHOLE_WEBPORT=${PIHOLE_WEBPORT}
EOF

  echo -e "${GREEN}.env erstellt mit folgenden Werten:${NC}"
  sed 's/^/  /' .env
}

##### 5) docker-compose.yaml erzeugen #####
generate_compose(){
  print_step "Erstelle docker-compose.yaml…"
  cat > docker-compose.yaml <<EOF
version: "3.8"
services:
  pihole-unbound:
    container_name: pihole-unbound
    image: mpgirro/pihole-unbound:latest
    network_mode: host
    hostname: \${HOSTNAME}
    domainname: \${DOMAIN_NAME}
    cap_add:
      - NET_ADMIN
      - SYS_TIME
      - SYS_NICE
    environment:
      - TZ=\${TZ:-UTC}
      - FTLCONF_webserver_api_password=\${WEBPASSWORD}
      - FTLCONF_webserver_interface_theme=\${WEBTHEME:-default-light}
      - FTLCONF_dns_upstreams=127.0.0.1#5335
      - FTLCONF_dns_listeningMode=all
      - FTLCONF_webserver_port=\${PIHOLE_WEBPORT}
    volumes:
      - etc_pihole-unbound:/etc/pihole:rw
      - etc_pihole_dnsmasq-unbound:/etc/dnsmasq.d:rw
    restart: unless-stopped

volumes:
  etc_pihole-unbound:
  etc_pihole_dnsmasq-unbound:
EOF
}

##### 6) Stack starten #####
start_stack(){
  print_step "Starte Pi-hole + Unbound…"
  docker-compose up -d
  echo -e "${GREEN}Fertig! Web UI: http://<HOST-IP>:\${PIHOLE_WEBPORT}${NC}"
}

##### Hauptablauf #####
main(){
  detect_os
  intro
  install_prereqs
  configure_docker_group
  clone_repo
  generate_env
  generate_compose
  start_stack
}

main
