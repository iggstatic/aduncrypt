# 🔒 AdUnCrypt - Privacy-Focused DNS Stack

![AdGuard Home](https://img.shields.io/badge/AdGuard%20Home-v0.107.79-green?logo=adguard)
![Build Status](https://img.shields.io/github/actions/workflow/status/iggstatic/aduncrypt/publish.yml?branch=master&label=Build&logo=github)
![License](https://img.shields.io/github/license/iggstatic/aduncrypt?logo=gnu)
![Multi-Arch](https://img.shields.io/badge/platform-linux%2Famd64%20%7C%20linux%2Farm64%20%7C%20linux%2Farm%2Fv7-blue?logo=docker)
![DNS Flow](https://img.shields.io/badge/DNS%20Flow-AdGuard%20→%20Unbound%20→%20DNSCrypt-blue)
![Privacy](https://img.shields.io/badge/Privacy-ODoH%20Enabled-green)
![Platform](https://img.shields.io/badge/Platform-Raspberry%20Pi%20Ready-orange)

A containerized DNS privacy solution combining [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome), [Unbound](https://nlnetlabs.nl/projects/unbound/about/), and [DNSCrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy) for enhanced privacy and ad-blocking. This project was inspired by [AdGuard-WireGuard-Unbound-DNScrypt](https://github.com/trinib/AdGuard-WireGuard-Unbound-DNScrypt). The goal is to streamline the original multi-step manual installation into a single, easy-to-deploy container while maintaining compatibility with standard AdGuard Home volume mappings.

## ✨ Features

- **Ad & tracker blocking** with AdGuard Home
- **DNS caching and DNSSEC validation** via [Unbound](https://nlnetlabs.nl/projects/unbound/about/) recursive resolver
- **Encrypted DNS** through DNSCrypt-proxy with ODoH ([Oblivious DNS-over-HTTPS](https://github.com/DNSCrypt/dnscrypt-proxy/wiki/Oblivious-DoH))
- **Anonymized routing** through relay servers for enhanced privacy
- **Automatic root hints updates** every 6 months via cron
- **Ready-to-deploy** with Podman/Docker Compose

## 🚀 Quick Start

### Prerequisites

Install Podman and Podman Compose:

```bash
sudo apt install podman podman-compose
```

### System Configuration

1. **Enable privileged port binding** (required for DNS port 53):
   By default, rootless Podman doesn't allow exposing a privileged port (<1024). Unless you are happy to use an unconventional DNS port to avoid an error, run:

```bash
echo "net.ipv4.ip_unprivileged_port_start=53" | sudo tee /etc/sysctl.d/20-dns-privileged-port.conf
```

2. **Optimize kernel buffers**:
   Unbound is configured with a larger kernel buffer so that no messages are lost during spikes in the traffic. To match the parameters in `unbound/unbound.conf` run:

```bash
echo "net.core.rmem_max=4194304" | sudo tee /etc/sysctl.d/99-unbound-buffers.conf
echo "net.core.wmem_max=4194304" | sudo tee -a /etc/sysctl.d/99-unbound-buffers.conf
```

3. **Apply changes**
```bash
sudo sysctl --system
```

### Deployment

Download this repo and spin up a container:

```bash
git clone https://github.com/iggstatic/aduncrypt.git
cd aduncrypt
podman-compose up -d
```

### Initial Setup

1. **Access AdGuard Home** at `http://<host-ip>:3000`, replacing `<host-ip>` with `localhost` if you’re running AdUnCrypt locally
2. **Follow the setup wizard** - when asked which interface to listen on, keep **All interfaces**

### Configure AdGuard Home

1. Delete everything from both **Upstream** and **Bootstrap DNS servers** options and add the following addresses to point at the Unbound resolver:

   - `127.0.0.1:5053` (Unbound)
   - `127.0.0.1:5353` (Direct fallback to Oblivious DNS over HTTPS)

2. Put a tick ☑ next to **Parallel Request** option.
3. In DNS settings, uncheck **Enable cache** or set **DNS cache size** to `0` (caching is handled by Unbound)
4. Add blocklists in **Filters** → **DNS blocklists**:
   - [Blocklists and Allowlists Sources](https://github.com/T145/black-mirror)

### Host System DNS Configuration

**Disable systemd-resolved** (if running):

```bash
sudo nano /etc/systemd/resolved.conf
# Set:
# DNS=127.0.0.1
# DNSStubListener=no
sudo systemctl restart systemd-resolved
```

**Update system resolver**:

```bash
# Check current configuration
cat /etc/resolv.conf

# Should contain: nameserver 127.0.0.1
# If not, update it:
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf
```

### Enable Auto-Start (Optional)

After completing initial setup, switch to the systemd deployment using Podman Quadlet (needs podman version >= 4.4).

> [!IMPORTANT]
> The provided Quadlet container file assumes that the AdUnCrypt project directory is located in your home folder, i.e. `~/aduncrypt/`. If you cloned it elsewhere, update all volume paths in `aduncrypt.container` accordingly — for example, replace `%h/aduncrypt/...` with the absolute path to your local copy.

```bash
# Stop compose (no longer needed)
podman-compose down

# Create systemd directory
mkdir -p ~/.config/containers/systemd

# Copy the quadlet container file to the systemd directory
cp aduncrypt.container ~/.config/containers/systemd/aduncrypt.container

# Reload systemd to recognize the new quadlet
systemctl --user daemon-reload

# Start the service
systemctl --user start aduncrypt.service

# Enable lingering for auto-start on boot
sudo loginctl enable-linger $USER

# Enable auto-updates
systemctl --user enable --now podman-auto-update.timer
```

### Alternative: Keep Using Compose

If you prefer manual management:

```bash
# Just restart when needed
podman-compose up -d
```

> [!NOTE]  
> Manual restart required after system reboot.

### Verify everything is working

```bash

# Check service status (if using Quadlet)
systemctl --user status aduncrypt.service

# Check container is running
podman ps

# View container logs
podman logs -f aduncrypt

# Test DNS resolution
dig @127.0.0.1 google.com

# Test auto-update capability
podman auto-update --dry-run

# Monitor systemd logs (if using Quadlet)
journalctl --user-unit=aduncrypt.service -b
```

## 🧪 Verification

Test your DNS setup with these tools:

- [1.1.1.1 Help](https://1.1.1.1/help) - Basic connectivity test
- [BrowserLeaks DNS](https://browserleaks.com/dns) - Should show "Cloudflare" if nothing is changed
- [DNSCheck Tools](https://dnscheck.tools/) - Comprehensive DNS analysis

## 📊 Ports

### Default Ports

| Port | Protocol | Service  | Description                             |
| ---- | -------- | -------- | --------------------------------------- |
| 53   | TCP/UDP  | DNS      | Primary DNS resolver                    |
| 80   | TCP      | HTTP     | AdGuard Home web panel                  |
| 3000 | TCP      | HTTP     | Initial setup **(disable after setup)** |
| 5053 | TCP/UDP  | Internal | Unbound DNS resolver                    |
| 5353 | TCP/UDP  | Internal | DNSCrypt-proxy                          |

> [!NOTE]  
> The Quadlet container doesn't expose port 3000. Complete the initial AdGuard Home setup using the compose method first, then switch to quadlet for production deployment.

### Optional Ports

The following ports are commented out in `compose.yml` but can be enabled as needed. For quadlet users, add them to your `aduncrypt.container` file using `PublishPort=` directives:

| Port | Protocol | Service       | Description                   |
| ---- | -------- | ------------- | ----------------------------- |
| 443  | TCP/UDP  | HTTPS         | AdGuard Home web panel HTTPS  |
| 784  | UDP      | DNS-over-QUIC | Modern encrypted DNS protocol |
| 853  | TCP      | DNS-over-TLS  | Encrypted DNS over TLS        |
| 67   | UDP      | DHCP Server   | Dynamic IP assignment         |
| 68   | UDP      | DHCP Client   | DHCP client responses         |

## 🔧 Customization

Unbound is configured to use [Oblivious DNS-over-HTTPS](https://github.com/DNSCrypt/dnscrypt-proxy/wiki/Oblivious-DoH) via `dnscrypt-proxy`. DNS over TLS is querying Cloudflare upstream endpoints. All configuration files are mounted as volumes for easy customization:

- **`unbound/unbound.conf`** - Unbound DNS resolver settings
- **`dnscrypt/dnscrypt-proxy.toml`** - DNSCrypt-proxy configuration
- **`adguard/adguard/opt-adguard-conf`** - AdGuard Home configuration
- **`adguard/adguard/opt-adguard-work`** - AdGuard Home data

You have full control to adjust the configuration as you see fit.

## 📝 Attribution

This project is inspired by and builds upon:

- [AdGuard-WireGuard-Unbound-DNScrypt](https://github.com/trinib/AdGuard-WireGuard-Unbound-DNScrypt) by trinib - Original comprehensive DNS privacy setup
- [adguard-unbound](https://github.com/lolgast1987/adguard-unbound) by lolgast1987 - Containerization approach

AdUnCrypt aims to make the original's excellent privacy-focused DNS configuration accessible through simplified container deployment.

## 🔗 Related Projects

- [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome)
- [Unbound](https://nlnetlabs.nl/projects/unbound/about/)
- [DNSCrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy)
