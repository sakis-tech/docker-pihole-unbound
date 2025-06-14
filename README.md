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

## Quick Install (One-Liner)

Run the installer directly using `wget` without cloning the repository:

```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/sakis-tech/docker-pihole-unbound/main/install-pihole-unbound.sh)"
```

1. **Follow the prompts**
   Choose whether to use the example configuration or enter custom settings.

2. **Provide macvlan network details**

   * Parent interface (e.g. `eth0`)
   * Subnet (e.g. `192.168.10.0/24`)
   * Gateway (e.g. `192.168.10.1`)
   * Pi-hole container IP address (e.g. `192.168.10.50`)

3. **Complete the installation**
   The script will configure everything and start the Docker containers.

4. **Access Pi-hole**
   Open your browser and navigate to `http://<Pi-hole_IP>:<Port>` using the IP and port you configured.

---

## Secure Unbound Setup

After Pi‑hole + Unbound are running, lock down your resolver with DNSSEC, root hints & trust anchor—all inside the container.
One‑Liner Secure‑Setup

```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/sakis-tech/docker-pihole-unbound/main/setup-pihole-unbound.sh)"
```

This script will:

* Download the latest root hints & DNSSEC trust anchor into the container
* Patch your Unbound include file (pi-hole.conf) to enable DNSSEC, harden glue, and point at the new files
* Restart Unbound inside pihole-unbound

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

