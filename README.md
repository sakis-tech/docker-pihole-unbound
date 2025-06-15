# Pi-hole + Unbound Docker Installer

A complete solution for automatically deploying Pi-hole with Unbound DNS resolver in Docker containers. This project enhances the [mpgirro/docker-pihole-unbound](https://github.com/mpgirro/docker-pihole-unbound) repository with improved installation scripts and user-friendly configuration options.

## Table of Contents

- [What is this?](#what-is-this)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Updating your Installation](#updating-your-installation)
- [Advanced Configuration](#advanced-configuration)

## What is this?

This project combines Pi-hole and Unbound into a powerful network solution:

- **Pi-hole** provides network-wide ad blocking and DNS filtering
- **Unbound** functions as a recursive DNS resolver for enhanced privacy
- **Docker** isolates these services for better security and easier management

The included scripts make installation and management simple even for beginners.

## Features

- 🐳 **Docker-based deployment** - Clean installation and easy maintenance
- 🔍 **Ad blocking** - Network-wide protection against ads and trackers
- 🔒 **Privacy protection** - Your own recursive DNS resolver with DNSSEC validation
- 🌐 **Macvlan networking** - Pi-hole appears as a separate device on your network
- ⚙️ **Easy configuration** - Edit settings directly from your host system
- 🔄 **One-click updates** - Keep everything current with minimal effort
- 🎨 **User-friendly scripts** - Color-coded output and status icons for clarity
- ✅ **Interactive setup** - Clear prompts guide you through the process

## Requirements

- 🐧 Linux system (tested on Debian, Ubuntu, CentOS, and Fedora)
- 🔧 `bash` shell and `sudo` privileges
- 🖧 Physical network interface for macvlan (e.g., `eth0`)
- 📦 Internet connection for downloading containers

## Installation

### One-Command Installation

Use this single command to install everything automatically:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sakis-tech/docker-pihole-unbound/main/install-pihole-unbound.sh)"
```

### What happens during installation:

1. **Prerequisite check** - Docker, Docker Compose, Git, and other required tools
2. **Interactive configuration** - You'll be prompted for:
   - Network details (interface, subnet, IP address)
   - Pi-hole settings (password, web port, theme)
   - Optional Portainer installation for container management
3. **Docker network setup** - Creates a macvlan network for your Pi-hole
4. **Container deployment** - Pulls and launches the Pi-hole with Unbound container

### After installation

1. Access the Pi-hole admin interface at `http://<Pi-hole_IP>:<Web_Port>`
2. Log in with the password you set during installation
3. Configure your devices to use the Pi-hole IP as their DNS server

---

## Configuration

### Unbound Configuration Setup

After your Pi-hole + Unbound installation is running, use this script to set up convenient host-based configuration:

```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/sakis-tech/docker-pihole-unbound/main/setup-pihole-unbound.sh)"
```

#### What the setup script does:

1. **Automatically finds** your Pi-hole installation directory
2. **Creates** a configuration directory structure on your host
3. **Extracts** the current Unbound configuration from the container
4. **Updates** docker-compose.yaml to mount the host configuration
5. **Restarts** the container with the new configuration

After running this script, you can edit Unbound configuration files directly on your host system without needing to access the container.

### User-Friendly Experience

All scripts in this project feature:

- **Color-coded output** for better readability
  - Blue headers for section titles
  - Green text for successful operations
  - Yellow notices for warnings and important information

- **Progress indicators** with informative icons
- **Clear confirmations** before any major changes
- **Detailed feedback** throughout the process

## Updating Your Installation

To update Pi-hole and Unbound to the latest versions, run:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sakis-tech/docker-pihole-unbound/main/update-pihole-unbound.sh)"
```

### Update Process

The update script automatically:

1. **Locates** your Pi-hole installation directory
2. **Downloads** the latest Docker images
3. **Restarts** containers with the updated images
4. **Displays** your current configuration
5. **Shows** container logs if requested

## Project Structure

After installation and setup, your project will have this structure:

```
/docker-pihole-unbound/
├── docker-compose.yaml    # Container configuration
├── .env                   # Environment variables
└── config/                # Configuration directory
    ├── pihole/            # Pi-hole configuration
    └── unbound/           # Unbound configuration
        └── pi-hole.conf   # DNS resolver settings
```

## Advanced Configuration

### Customizing Unbound DNS Resolver

After running the setup script, you can customize Unbound by editing:

```
./config/unbound/pi-hole.conf
```

This file contains the configuration for your DNS resolver including DNSSEC settings, caching parameters, and other DNS-related options.

### Applying Configuration Changes

After making changes to any configuration files, restart the container:

```bash
docker compose restart pihole-unbound
```

### Additional Pi-hole Settings

While most Pi-hole settings can be managed through the web interface, advanced configurations can be found in:

```
./config/pihole/
```

### Common Tasks

- **View Pi-hole logs**: `docker compose logs pihole-unbound`
- **Access Pi-hole container**: `docker compose exec pihole-unbound bash`
- **Update gravity list**: `docker compose exec pihole-unbound pihole -g`

## Troubleshooting

### Container Issues
- **Container not starting**: Check logs with `docker compose logs pihole-unbound`
- **Permission problems**: If you've added your user to the docker group, log out and back in

### Network Issues
- **Network connectivity issues**: Verify your macvlan configuration matches your network settings
- **DNS resolution problems**: Ensure your router is correctly forwarding DNS queries to Pi-hole
- **Can't access admin interface**: Check if the IP address and port are correct

### DNS Functionality
- **Some domains not resolving**: Check for domain-specific blocks in Pi-hole's query log
- **Slow DNS resolution**: Verify your upstream DNS servers in Unbound configuration

## Support

For issues related to these scripts, please open an issue in this repository.

For Pi-hole specific questions, refer to the [Pi-hole documentation](https://docs.pi-hole.net/).

For Unbound configuration options, see the [Unbound documentation](https://unbound.docs.nlnetlabs.nl/).

---

## Network Configuration

The installer creates a Docker macvlan network called `pihole_macvlan` that allows the Pi-hole container to appear as a separate physical device on your network with its own IP address.

This approach has several benefits:
- Direct accessibility from all network devices
- Can function as your network's DHCP server if desired
- Cleaner network architecture (no port forwarding required)

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
