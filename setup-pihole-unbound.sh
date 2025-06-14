#!/usr/bin/env bash
set -euo pipefail

# Colors & Icons
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[1;34m'
NC='\033[0m'

CHECK="✅"
CROSS="❌"
GEAR="⚙️"
DOWN="⬇️"

CONTAINER="pihole-unbound"
UNBOUND_DIR="/etc/unbound"
CONF_FILE="${UNBOUND_DIR}/unbound.conf.d/pi-hole.conf"
ROOT_HINTS_URL="https://www.internic.net/domain/named.root"
ROOT_KEY_URL="https://www.internic.net/domain/root.key"

echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}  🔒 Secure Unbound Setup for '${CONTAINER}'${NC}"
echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"

# 1) Ensure container is running
echo -e "${GEAR} Checking container '${CONTAINER}'…"
if ! docker ps --format '{{.Names}}' | grep -qw "${CONTAINER}"; then
  echo -e "${RED}${CROSS} '${CONTAINER}' is not running. Start it first!${NC}"
  exit 1
fi

# 2) Install curl inside container if missing
echo -e "${GEAR} Installing curl inside container…"
docker exec "${CONTAINER}" bash -c "\
  if ! command -v curl &>/dev/null; then \
    apt-get update && apt-get install -y curl; \
  fi"

# 3) Download root hints & trust anchor
echo -e "${DOWN} Downloading root hints…"
docker exec "${CONTAINER}" curl -fsSL "${ROOT_HINTS_URL}" -o "${UNBOUND_DIR}/root.hints"
echo -e "${DOWN} Downloading DNSSEC trust anchor…"
docker exec "${CONTAINER}" curl -fsSL "${ROOT_KEY_URL}" -o "${UNBOUND_DIR}/root.key"

# 4) Patch Unbound config
echo -e "${GEAR} Patching Unbound config…"
docker exec "${CONTAINER}" bash -c "\
  sed -i 's|# *logfile:.*|logfile: \"${UNBOUND_DIR}/unbound.log\"|' ${CONF_FILE} || true; \
  sed -i '/^\\s*harden-glue:/d' ${CONF_FILE}; \
  sed -i '/^\\s*server:/a\\    harden-glue: yes' ${CONF_FILE}; \
  sed -i '/^\\s*harden-dnssec-stripped:/d' ${CONF_FILE}; \
  sed -i '/^\\s*server:/a\\    harden-dnssec-stripped: yes' ${CONF_FILE}; \
  sed -i 's|# *root-hints:.*|root-hints: \"${UNBOUND_DIR}/root.hints\"|' ${CONF_FILE}; \
  if ! grep -q '^ *auto-trust-anchor-file:' ${CONF_FILE}; then \
    sed -i '/^\\s*server:/a\\    auto-trust-anchor-file: \"${UNBOUND_DIR}/root.key\"' ${CONF_FILE}; \
  else \
    sed -i 's|^ *auto-trust-anchor-file:.*|auto-trust-anchor-file: \"${UNBOUND_DIR}/root.key\"|' ${CONF_FILE}; \
  fi"

# 5) Restart Unbound
echo -e "${GEAR} Restarting Unbound…"
docker exec "${CONTAINER}" bash -c "service unbound restart || kill -HUP \$(pidof unbound)"

echo -e "${GREEN}${CHECK} Unbound is now secured with DNSSEC, root hints & trust anchor.${NC}"
