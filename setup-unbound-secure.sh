#!/usr/bin/env bash
set -euo pipefail

CONTAINER="pihole-unbound"
UNBOUND_DIR="/etc/unbound"
CONF_FILE="${UNBOUND_DIR}/unbound.conf.d/pi-hole.conf"

# URLs for root hints and DNSSEC trust anchor
ROOT_HINTS_URL="https://www.internic.net/domain/named.root"
ROOT_KEY_URL="https://www.internic.net/domain/root.key"

echo "🔍 Checking that container '${CONTAINER}' is running…"
if ! docker ps --format '{{.Names}}' | grep -qw "${CONTAINER}"; then
  echo "❌ Container '${CONTAINER}' is not running. Start it and re-run."
  exit 1
fi

echo "📦 Installing curl inside container (if missing)…"
docker exec "${CONTAINER}" bash -c \
  "if ! command -v curl &>/dev/null; then \
     apt-get update && apt-get install -y curl; \
   fi"

echo "⬇️  Downloading root hints into container…"
docker exec "${CONTAINER}" bash -c \
  "curl -fsSL ${ROOT_HINTS_URL} -o ${UNBOUND_DIR}/root.hints"

echo "⬇️  Downloading DNSSEC trust anchor (root.key)…"
docker exec "${CONTAINER}" bash -c \
  "curl -fsSL ${ROOT_KEY_URL} -o ${UNBOUND_DIR}/root.key"

echo "🛠 Patching Unbound config (${CONF_FILE})…"
docker exec "${CONTAINER}" bash -c "
  # ensure include directory exists
  mkdir -p \$(dirname ${CONF_FILE})

  # uncomment/add logfile if desired (optional)
  sed -i 's|# *logfile:.*|logfile: \"${UNBOUND_DIR}/unbound.log\"|' ${CONF_FILE} || true

  # enable DNSSEC and harden glue
  sed -i '/^\\s*harden-glue:/d' ${CONF_FILE}
  sed -i '/^\\s*server:/a\\    harden-glue: yes' ${CONF_FILE}

  sed -i '/^\\s*harden-dnssec-stripped:/d' ${CONF_FILE}
  sed -i '/^\\s*server:/a\\    harden-dnssec-stripped: yes' ${CONF_FILE}

  # point at our hints & key
  sed -i 's|# *root-hints:.*|root-hints: \"${UNBOUND_DIR}/root.hints\"|' ${CONF_FILE}
  if ! grep -q '^ *auto-trust-anchor-file:' ${CONF_FILE}; then
    sed -i '/^\\s*server:/a\\    auto-trust-anchor-file: \"${UNBOUND_DIR}/root.key\"' ${CONF_FILE}
  else
    sed -i 's|^ *auto-trust-anchor-file:.*|auto-trust-anchor-file: \"${UNBOUND_DIR}/root.key\"|' ${CONF_FILE}
  fi
"

echo "🔄 Restarting Unbound inside container…"
docker exec "${CONTAINER}" bash -c "service unbound restart || kill -HUP \$(pidof unbound)"

echo "✅ Unbound is now configured with DNSSEC, root hints, and the trust anchor."
