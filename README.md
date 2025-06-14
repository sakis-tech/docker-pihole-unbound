# Pi-hole + Unbound Auto-Installer

This project is an automatic installer script based on the repository [mpgirro/docker-pihole-unbound](https://github.com/mpgirro/docker-pihole-unbound).

It sets up Pi-hole with the Unbound DNS resolver as Docker containers and automates the installation of all required components.

---

## Features

- Automatic installation of Docker & Docker Compose  
- Installation of Git and Curl if needed  
- Clones the original repository `mpgirro/docker-pihole-unbound`  
- Creates `.env` and `docker-compose.yaml` files  
- Sets up a Docker macvlan network  
- Launches Pi-hole + Unbound as Docker containers  
- Supports Pi-hole’s DHCP server functionality  

---

## Requirements

- Linux system (tested on Debian, Ubuntu, CentOS, Fedora)  
- `bash` and `sudo` privileges  
- A physical network interface for macvlan (e.g., `eth0`)  

---

## Installation

### Run as one-liner (direct execution)

You must run the installer directly wget without cloning the repo:
```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/sakis-tech/docker-pihole-unbound/main/install.sh)"
```
Follow the prompts:
* Choose between example config or custom settings
* Provide macvlan network details (parent interface, subnet, gateway, container IP)
* Once complete, access Pi-hole at the configured IP address and port.
---

## Accessing the Web Interface

* URL: `http://<Pi-hole-IP>:<Web-Port>`
* Default web password (if example config used): `admin`

---

## Directory Structure

* `config/pihole` – Pi-hole configuration and data
* `config/unbound` – Unbound resolver configuration

---

## Docker Network

The script creates a Docker macvlan network named `pihole_macvlan` to allow the Pi-hole container to appear as a separate host on your network.

---

## Tips

* Restart containers after configuration changes:

  ```bash
  docker-compose restart
  ```

* If your user is added to the Docker group, log out and back in before rerunning the script.

---

## License

MIT

---

## Note

This script is intended for personal use. Please verify your network settings and security configurations before using in production.

