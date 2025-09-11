# Pi-hole Deployment Guide

## Prerequisites

- **Raspberry Pi 3B** running DietPi OS
- **IP Address**: 192.168.144.20 (Network Services range)
- **Hostname**: pihole
- **SSH Access**: jan user with sudo privileges

## Container Deployment

### Storage Configuration

```bash
# Create Pi-hole directories
sudo mkdir -p /opt/pihole/etc-pihole
sudo mkdir -p /opt/pihole/etc-dnsmasq.d

# Set proper ownership
sudo chown jan:jan /opt/pihole
sudo chown -R jan:jan /opt/pihole/
```

### Pi-hole Container Deployment

```bash
# Deploy Pi-hole container
sudo podman run -d \
  --name pihole \
  --restart unless-stopped \
  --network host \
  -e TZ=Europe/Amsterdam \
  -e WEBPASSWORD=<PASSWORD> \
  -v /opt/pihole/etc-pihole:/etc/pihole:rw \
  -v /opt/pihole/etc-dnsmasq.d:/etc/dnsmasq.d:rw \
  docker.io/pihole/pihole:latest
```

**Container Configuration:**
- **Image**: `docker.io/pihole/pihole:latest`
- **Network**: Host mode (ports 53, 67, 80)
- **Restart**: unless-stopped
- **Timezone**: Europe/Amsterdam
- **Web Password**: <PASSWORD>

### Network Configuration

**Pi-hole Network Settings:**
- **Primary Interface**: eth0
- **IP Address**: 192.168.144.20/23
- **Gateway**: 192.168.144.1
- **DNS Upstream**: 1.1.1.1, 1.0.0.1, 8.8.8.8, 8.8.4.4

## DHCP Configuration

### Enable Pi-hole DHCP

1. **Access Pi-hole Admin**: http://192.168.144.20/admin
2. **Login**: Password: `<PASSWORD>`
3. **Settings → DHCP**: Enable DHCP server
4. **DHCP Range**: `192.168.145.1` to `192.168.145.254`
5. **Router (Gateway)**: `192.168.144.1`
6. **DHCP lease time**: 24 hours

### Fritz!Box DHCP Disable

**CRITICAL**: Disable Fritz!Box DHCP to prevent conflicts:
1. Access Fritz!Box admin interface
2. Navigate to Home Network → Network → Network Settings
3. Disable "Act as DHCP server"
4. Save configuration

### TOML Configuration Method

**Configuration file**: `/opt/pihole/etc-pihole/pihole.toml`

Pi-hole v6 uses a single TOML file for DNS, DHCP, and related settings.  
To integrate internal services and split-horizon DNS:

- **DHCP section**  
  Define the DHCP range, gateway, domain, and any static leases you need.  
  Example:
  ```toml
  [dhcp]
  enabled = true
  start = "192.168.145.1"
  end = "192.168.145.254"
  router = "192.168.144.1"
  lease_time = "24h"
  domain = "local"
  hosts = [
      "aa:bb:cc:dd:ee:ff,192.168.144.160,mydevice,infinite"
  ]
  ```

- **DNS section**  
  For each internal service, add an entry mapping its LAN IP to the desired hostname(s).  
  Example:
  ```toml
  [dns]
  hosts = [
      "192.168.144.31 lanproxy.local lanproxy",
      "192.168.144.31 service1.example.com",
      "192.168.144.31 service2.example.com"
  ]
  ```

  Notes:
  - Use the service’s dedicated LXC IP or the central reverse proxy IP (`lanproxy`) if you front services there.  
  - You can list multiple hostnames for the same IP, separated by spaces.  
  - Always add both your `.local` shortnames and any external DNS names you want Pi-hole to resolve internally.

- **dnsmasq lines for split-horizon**  
  For each externally visible domain you want to resolve internally, add a `local=/domain/` directive.  
  Example:
  ```toml
  dnsmasq_lines = [
      "dhcp-option=15,local",
      "local=/service1.example.com/",
      "local=/service2.example.com/"
  ]
  ```

---

**Process when adding a new service**:
1. Assign it a static IP in the correct range.  
2. Add the corresponding entry to `[dns].hosts`.  
3. If the service has an external hostname, add a `local=/…/` entry under `dnsmasq_lines`.  
4. Restart Pi-hole:  
   ```bash
   sudo systemctl restart pihole-FTL
   ```

## DNS Configuration

### Upstream DNS Servers
Configure reliable upstream DNS servers:
- **Primary**: 1.1.1.1 (Cloudflare)
- **Secondary**: 1.0.0.1 (Cloudflare)
- **Tertiary**: 8.8.8.8 (Google)
- **Quaternary**: 8.8.4.4 (Google)

### Local Domain Resolution
- **Domain**: `.local` 
- **DHCP clients**: Automatically get `.local` domain
- **Static devices**: Manually configured in TOML hosts array

## Firewall Configuration

### UFW Rules
```bash
# Allow DNS
sudo ufw allow 53/tcp
sudo ufw allow 53/udp

# Allow DHCP
sudo ufw allow 67/udp

# Allow web interface
sudo ufw allow 80/tcp

# Allow from local network only
sudo ufw allow from 192.168.144.0/23
sudo ufw allow from 192.168.145.0/24

# Verify rules
sudo ufw status
```

## Access URLs

### Internal Access
- **Pi-hole Admin**: http://192.168.144.20/admin or http://pihole.local/admin
- **Login Password**: `<PASSWORD`

### Service Testing
```bash
# Test DNS resolution
nslookup google.com 192.168.144.20
nslookup pihole.local 192.168.144.20

# Test local hostname resolution
nslookup server.local
nslookup homeassistant.local
```

## Verification Steps

### DNS Service Testing
```bash
# Test DNS service is running
sudo systemctl status pihole
sudo podman ps | grep pihole

# Test DNS queries
dig @192.168.144.20 google.com
nslookup nu.nl 192.168.144.20
```

### DHCP Service Testing
```bash
# Check DHCP leases (on a client device)
sudo dhclient -r && sudo dhclient

# Verify client configuration
cat /etc/resolv.conf
# Should show:
# domain local
# search local
# nameserver 192.168.144.20
```

## Troubleshooting

### DNS Resolution Issues

**Local hostnames not resolving:**
- Verify hosts entries in TOML configuration
- Check Pi-hole is running: `sudo podman ps`
- Test direct queries: `nslookup server.local 192.168.144.20`
- Verify client is using Pi-hole as DNS: `cat /etc/resolv.conf`

**External domains not resolving:**
- Check upstream DNS servers in configuration
- Verify internet connectivity from Pi-hole
- Check Pi-hole blocking isn't interfering

### DHCP Issues

**No DHCP leases being assigned:**
- Verify only one DHCP server is active on network
- Check Fritz!Box DHCP is disabled
- Verify Pi-hole DHCP is enabled in web interface
- Check firewall allows ports 67/68 UDP
- Review Pi-hole logs: `sudo podman logs pihole | grep -i dhcp`

**Clients not getting .local domain:**
- Verify DHCP domain setting is "local"
- Check Pi-hole DHCP configuration
- Force client DHCP renewal: `sudo dhclient -r && sudo dhclient`

### Container Issues

**Container won't start:**
- Check required directories exist with correct permissions
- Verify no port conflicts (53, 67, 80)
- Review container logs: `sudo podman logs pihole`

**Configuration changes not applied:**
- Restart container: `sudo podman restart pihole`
- For major changes, recreate container with deployment command

## Maintenance

### Updating Pi-hole
```bash
# Pull latest image
sudo podman pull docker.io/pihole/pihole:latest

# Recreate container with new image
sudo podman stop pihole
sudo podman rm pihole
# Run deployment command with latest image
```

### Configuration Backup
```bash
# Backup Pi-hole configuration
sudo tar -czf pihole-backup-$(date +%Y%m%d).tar.gz /opt/pihole/

# Configuration locations:
# - /opt/pihole/etc-pihole/pihole.toml (main configuration)
# - /opt/pihole/etc-pihole/pihole-FTL.db (query database)
# - /opt/pihole/etc-pihole/gravity.db (blocklist database)
```

### Adding New Network Services

When deploying new services, update the Pi-hole TOML configuration:

1. **For DNS hostname resolution**:
   ```bash
   sudo nvim /opt/pihole/etc-pihole/pihole.toml
   ```
   Add to `hosts` array under `[dns]`:
   ```toml
   "IP_ADDRESS hostname.local hostname"
   ```

2. **For fixed IP DHCP assignments**:
   Add to `hosts` array under `[dhcp]`:
   ```toml
   "MAC_ADDRESS,IP_ADDRESS,HOSTNAME,infinite"
   ```

3. **Apply changes**:
   ```bash
   sudo podman restart pihole
   ```

4. **Test resolution**: 
   ```bash
   nslookup hostname.local
   ```

---

**Pi-hole Status**: Active at 192.168.144.20  
**Web Interface**: http://192.168.144.20/admin  
**Network Role**: Primary DNS and DHCP server for entire network
