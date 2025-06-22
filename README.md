# Pi-hole + Unbound Docker Installer

A complete solution for automatically deploying Pi-hole with Unbound DNS resolver in Docker containers. This project enhances the [mpgirro/docker-pihole-unbound](https://github.com/mpgirro/docker-pihole-unbound) repository with improved installation scripts and user-friendly configuration options.

## Table of Contents

- [What is this?](#what-is-this)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Updating Your Installation](#updating-your-installation)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)
- [Network Configuration](#network-configuration)
- [Support](#support)
- [License](#license)

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

### Option 1: One-Command Installation

If `curl` is already installed on your system, use this single command to install everything automatically:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sakis-tech/docker-pihole-unbound/main/install-pihole-unbound.sh)"
```

### Option 2: Two-Step Installation (for fresh systems)

For newly installed systems that don't have `curl` yet:

```bash
# Step 1: Install curl
sudo apt update && sudo apt install -y curl

# Step 2: Run the installer
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sakis-tech/docker-pihole-unbound/main/install-pihole-unbound.sh)"
```

### What happens during installation:

1. **Prerequisite check** - Docker, Docker Compose, Git, and other required tools
2. **Interactive configuration** - You'll be prompted for:
   - Network details (interface, subnet, IP address)
   - Pi-hole settings (password, web port, theme)
   - Optional Portainer installation for container management
3. **Docker network setup** - Creates a macvlan network for your Pi-hole
4. **Container deployment** - Pulls and launches the Pi-hole with Unbound container using Named Volumes
5. **Optional cleanup** - Remove all files except docker-compose.yaml and .env if desired

> ⚠️ **Important IP Address Note:**  
> When configuring the Pi-hole IP address, you **MUST** use a different IP than your host machine. This is required for the Docker macvlan network setup to work properly.
> 
> **Example:**  
> - If your host machine has IP address `192.168.1.10`
> - Set Pi-hole to something like `192.168.1.20` (but still within your subnet)
> - Make sure this IP is not already in use by another device

### After installation

1. Access the Pi-hole admin interface at `http://<Pi-hole_IP>:<Web_Port>`
2. Log in with the password you set during installation
3. Configure your devices to use the Pi-hole IP as their DNS server

---

## Configuration

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
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/sakis-tech/docker-pihole-unbound/main/update-pihole-unbound.sh)"
```

### Update Process

The update script automatically:

1. **Locates** your Pi-hole installation directory
2. **Records** current Pi-hole and Unbound versions
3. **Downloads** the latest Docker images
4. **Restarts** containers with the updated images
5. **Shows version changes** comparing old and new versions
6. **Tests DNS resolution** against common domains
7. **Displays** your current configuration
8. **Shows** container logs if requested

## Project Structure

After installation, your project directory will include:

```
./
├── docker-compose.yaml  # Container configuration
└── .env                 # Environment variables
```

The installer creates three Docker named volumes with shorter, more manageable names:

```
Docker Volumes:
├── pihole    # Pi-hole configuration storage
├── dnsmasq   # DNS configuration storage
└── unbound   # Unbound core configuration storage
```

### Common Tasks

- **View Pi-hole logs**: `docker compose logs pihole-unbound`
- **Access Pi-hole container**: `docker compose exec pihole-unbound bash`
- **Update gravity list**: `docker compose exec pihole-unbound pihole -g`

---

## Network Configuration

The installer creates a Docker macvlan network called `pihole_macvlan` that allows the Pi-hole container to appear as a separate physical device on your network with its own IP address.

This approach has several benefits:
- Direct accessibility from all network devices
- Can function as your network's DHCP server if desired
- Cleaner network architecture (no port forwarding required)

### Recommended Host Configuration with macvlan

Since we're using macvlan, the host machine cannot directly access the container. To still allow DNS resolution from the host:

1. Configure your router as the DNS server in `/etc/resolv.conf` on the host:
   ```
   nameserver 192.168.10.1  # Replace with your router's IP
   ```

2. Configure your router to use Pi-hole (192.168.10.20) as its DNS server

This creates a path where: Host → Router → Pi-hole → Internet

## Troubleshooting

### Portainer Time-out

If you see the following message when accessing Portainer:

```
New Portainer installation
Your Portainer instance timed out for security purposes. To re-enable your Portainer instance, you will need to restart Portainer.
```

This is a security feature of Portainer. To fix this issue, simply restart the Portainer container:

```bash
docker restart portainer
```

After restarting, you'll be able to access the Portainer interface again and complete the initial setup.

## Support

For issues related to these scripts, please open an issue in this repository.

For Pi-hole specific questions, refer to the [Pi-hole documentation](https://docs.pi-hole.net/).

For Unbound configuration options, see the [Unbound documentation](https://unbound.docs.nlnetlabs.nl/).

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
