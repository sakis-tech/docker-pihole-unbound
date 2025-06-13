# Pi-hole with Unbound Docker Setup

This repository provides a simple, interactive installer script and Docker Compose configuration to run Pi-hole with built-in DHCP and Unbound as a local DNS resolver. The setup uses the `mpgirro/pihole-unbound` image and host networking for maximum compatibility.

## Features

- **Interactive Installer (**\`\`**)**

  - Creates necessary configuration directories
  - Downloads `root.hints` and initializes `root.key` for Unbound
  - Generates a basic `unbound.conf` and opens it for review
  - Prompts for key environment variables and writes to `.env`
  - Writes a ready-to-use `docker-compose.yaml`

- **Pi-hole**

  - DNS server with built-in DHCP support
  - Web interface for administration
  - Customizable theme, port, and password via environment variables

- **Unbound**

  - Local, caching DNS resolver with DNSSEC support
  - Automatically fetches root zone hints and trust anchors

## Prerequisites

- Docker & Docker Compose installed on your host
- Unix-like shell environment (Linux, macOS, WSL)
- `curl` and `unbound-anchor` available on the system running the installer script

## Repository Structure

```text
├── install.sh           # Interactive installer script
├── docker-compose.yaml  # Generated Compose file (do not edit directly)
├── .env                 # Generated environment variables file
└── config/
    └── unbound/
        ├── root.hints   # Root zone hints for Unbound
        ├── root.key     # DNSSEC trust anchor
        └── unbound.conf # Unbound configuration (editable)
```

## Installation

```bash
# Make the installer executable
chmod +x install.sh

# Run the installer
./install.sh
```

During the installation, you will be prompted to enter:

- **Hostname** for the Docker container
- **Domain name** (optional)
- **Time zone** (e.g., `Europe/Berlin`)
- **Web admin password** for Pi-hole
- **Web UI theme** (defaults to `default-light`)
- **Web UI port** (defaults to `80`)

After completion, you will have a `.env` file and a `docker-compose.yaml` ready to use.

## Running the Stack

Start the services in detached mode:

```bash
docker-compose up -d
```

You can monitor the logs:

```bash
docker-compose logs -f
```

Access the Pi-hole Web interface at `http://<host-ip>:<PIHOLE_WEBPORT>`.

## Customization

- **Updating Unbound Configuration**

  - Edit `config/unbound/unbound.conf` to adjust Unbound settings.
  - After changes, restart the container:
    ```bash
    docker-compose restart pihole-unbound
    ```

- **Adding Block Lists / Custom DNS Rules**

  - Use the Pi-hole web interface under **Group Management** → **Adlists**.

- **DHCP Settings**

  - Enable or adjust DHCP settings via the Pi-hole web interface under **Settings** → **DHCP**.

## Updating

If a new version of `mpgirro/pihole-unbound` is released:

```bash
docker-compose pull
docker-compose up -d
```

## Troubleshooting

- Ensure `unbound-anchor` ran without errors and `root.key` exists.
- Verify correct file permissions for `config/unbound` directory.
- Check Docker logs for errors:
- docker logs pihole-unbound
