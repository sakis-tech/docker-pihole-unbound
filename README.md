# Pi-hole + Unbound Docker Installer

A complete solution for automatically deploying Pi-hole with Unbound DNS resolver as Docker containers. This project builds upon the excellent [mpgirro/docker-pihole-unbound](https://github.com/mpgirro/docker-pihole-unbound) repository with enhanced installation scripts and configuration options.

## Overview

This project provides a comprehensive set of scripts to:

1. **Install** - Set up Pi-hole and Unbound in Docker containers
2. **Configure** - Easily manage Unbound settings from your host system
3. **Update** - Keep your installation up to date

---

## Features

- 🐳 **Docker-based installation** - Everything runs in containers for better isolation
- 🔍 **Pi-hole DNS filtering** - Block ads and trackers at the network level
- 🔒 **Unbound recursive resolver** - Control your own DNS resolution chain
- 🌐 **Macvlan networking** - Makes Pi-hole appear as a separate device on your network
- ⚙️ **Host-based configuration** - Edit Unbound settings directly from your host
- 🔄 **Automatic updates** - Keep everything current with the update script
- 🎛️ **DHCP support** - Optional DHCP server functionality

---

## Requirements

- 🐧 Linux system (tested on Debian, Ubuntu, CentOS, Fedora)
- 🔧 `bash` and `sudo` privileges
- 🖧 A physical network interface for macvlan (e.g., `eth0`)
- 📦 Internet connection for downloading Docker and containers

---

## Quick Installation Guide

### 1. One-Line Installer

Run the following command to install everything in one go:

```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/sakis-tech/docker-pihole-unbound/main/install-pihole-unbound.sh)"
```

### 2. Follow the prompts

- Choose between example configuration or custom settings
- Configure the network settings:
  - Parent interface (e.g., `eth0`)
  - Network subnet (e.g., `192.168.10.0/24`)
  - Gateway address (e.g., `192.168.10.1`)
  - Pi-hole IP address (e.g., `192.168.10.50`)

### 3. Initial Access

When installation completes:
1. Open your browser and navigate to `http://<Pi-hole_IP>:<Port>`
2. Log in with the password you specified during installation

---

## Unbound Configuration Setup

After your Pi-hole + Unbound installation is running, use this script to set up convenient host-based configuration:

```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/sakis-tech/docker-pihole-unbound/main/setup-pihole-unbound.sh)"
```

### What the setup script does:

1. **Automatically finds** your Pi-hole + Unbound installation directory
2. **Creates** a configuration directory structure on your host
3. **Extracts** the Unbound configuration from the container
4. **Configures** docker-compose.yaml to mount the host configuration directory
5. **Restarts** the container with the new mount points

After running this script, you can edit Unbound configuration files directly from your host system.

---

## Project Structure

```
/
├── config/
│   ├── pihole/     # Pi-hole configuration and data
│   └── unbound/    # Unbound configuration files
│       └── unbound.conf.d/  # Custom Unbound configurations
├── docker-compose.yaml      # Container definitions
└── .env                     # Environment variables
```

---

## Network Configuration

The installer creates a Docker macvlan network called `pihole_macvlan` that allows the Pi-hole container to appear as a separate physical device on your network with its own IP address.

This approach has several benefits:
- Direct accessibility from all network devices
- Can function as your network's DHCP server if desired
- Cleaner network architecture (no port forwarding required)

---

## Maintenance & Updates

### Updating the installation

To update Pi-hole and Unbound to the latest versions:

```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/sakis-tech/docker-pihole-unbound/main/update-pihole-unbound.sh)"
```

### Applying Configuration Changes

After editing Unbound configuration files, restart the container to apply changes:

```bash
docker-compose restart pihole-unbound
```

---

## Advanced Configuration

### Customizing Unbound

Edit the Unbound configuration at:
```
./config/unbound/unbound.conf.d/pi-hole.conf
```

### Pi-hole Custom Settings

Most Pi-hole settings can be managed through the web interface. For advanced configurations, see the Pi-hole documentation for settings stored in:
```
./config/pihole/
```

---

## Troubleshooting

- **Container not starting**: Check the logs with `docker logs pihole-unbound`
- **Network connectivity issues**: Verify your macvlan configuration matches your network
- **DNS resolution problems**: Ensure your router is correctly forwarding DNS queries
- **Permission problems**: If you've added your user to the docker group, log out and back in

---

## License

MIT

---

## Acknowledgments

- [Pi-hole](https://pi-hole.net/) - Network-wide ad blocking
- [Unbound](https://nlnetlabs.nl/projects/unbound/about/) - Validating, recursive DNS resolver
- [mpgirro/docker-pihole-unbound](https://github.com/mpgirro/docker-pihole-unbound) - Original container implementation

---

## Disclaimer

This project is intended for personal or educational use. Please ensure your network settings and security configurations are appropriate for your environment before using in production.
