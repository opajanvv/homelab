# Infrastructure Catalog - Current State

*Single source of truth for all infrastructure components, services, and network configuration*

## Physical Infrastructure

### Core Hardware

| Device | Role | IP Address | Hardware | OS | Notes |
|--------|------|------------|----------|-----|-------|
| Proxmox Server | Container/VM host platform | 192.168.144.10 | Physical server | Proxmox VE 8.2 | 2x NVMe, 2x SSD, 2x HDD pools |
| Raspberry Pi 3B | DNS service (Pi-hole) | 192.168.144.20 | Raspberry Pi 3B | DietPi OS | Primary DNS server |
| Raspberry Pi 1B | Status monitoring | 192.168.144.25 | Raspberry Pi 1B | DietPi OS | Network status dashboard |

## VM and Container ID Allocation

### ID Numbering Strategy
- **Sequential allocation**: All VMs and containers use sequential IDs starting from 100
- **Gap filling**: When a VM/container is deleted, new deployments fill the lowest available gap
- **Service range**: 100-899 (VMs and containers)
- **Template range**: 901-999 (LXC templates)

### ID Assignment Process
1. Check current assignments: `pct list && qm list`
2. Assign lowest available ID in service range (100-899)
3. Update this catalog with new assignment
4. No ID reservation - assign at deployment time

## Storage and Backup Configuration

### Storage Architecture

**Proxmox Storage Pools:**
- **nvme_pool**: 2x NVMe 1TB (mirror) - 928GB usable - VM disks
- **ssd_pool**: 2x SSD 4TB (mirror) - 3.62TB usable - Container data  
- **media_pool**: 2x HDD 2TB (mirror) - 1.81TB usable - Media files
- **backup_pool**: 1x HDD 1TB - 928GB usable - Backups, ISOs
- **rpool**: 1x SSD 250GB - 230GB usable - Proxmox system

### Service Storage Allocation

**All LXC services follow standardized pattern**: `/lxcdata/<service>` → `/data`

| Service | Host Path | Container Mount | Special Mounts | Storage Pool |
|---------|-----------|-----------------|----------------|--------------|
| PostgreSQL | `/lxcdata/postgresql` | `/data` | - | ssd_pool |
| MariaDB | `/lxcdata/mariadb` | `/data` | - | ssd_pool |
| Planka | `/lxcdata/planka` | `/data` | - | ssd_pool |
| n8n | `/lxcdata/n8n` | `/data` | - | ssd_pool |
| WordPress JokeGoudriaan | `/lxcdata/wp-jokegoudriaan` | `/data` | - | ssd_pool |
| WordPress Kledingruil | `/lxcdata/wp-kledingruil` | `/data` | - | ssd_pool |
| Plex | `/lxcdata/plex` | `/data` | `/media` → `/media` | ssd_pool + media_pool |
| Tunnel | No mounts | - | - | ssd_pool |
| Lan Proxy | `lxcdata/lanproxy` | `/data` | - | ssd_pool |
| Home Assistant | VM disk only | - | - | nvme_pool |

### Backup System

**Two-Layer Enterprise Backup Strategy:**

**Layer 1: VM/Container Snapshots**
- **Schedule**: Daily at 3:00 AM (Proxmox vzdump)
- **Coverage**: All 8 VMs and containers (7 service LXCs + 1 appliance VM)
- **Retention**: 2 days  
- **Storage**: `/backups/dump/`

**Layer 2: Data-Level Incremental**  
- **Schedule**: Daily at 1:00 AM (rsync)
- **Coverage**: All `/lxcdata/*` persistent data
- **Retention**: 7 days
- **Storage**: `/backup_pool/lxcdata-backups/`

**Service-Specific Backup Notes:**
- **Home Assistant**: Built-in backup supplements VM snapshots
- **WordPress Sites**: All content covered by data-level backups
- **All databases**: Covered by both backup layers

## Network Configuration

### Network Architecture
- **Primary Network**: 192.168.144.0/23
- **Static Services**: 192.168.144.0/24 (infrastructure and services)
- **DHCP Pool**: 192.168.145.0/24 (dynamic client assignments)
- **Gateway**: Fritz!Box router (192.168.144.1)
- **Primary DNS**: Pi-hole (192.168.144.20)
- **Internal Domain**: .local

### IP Range Allocation Strategy

**Design Principles:**
1. **Logical Grouping**: Services grouped by function and management requirements
2. **Room for Growth**: Each category has expansion space within its range
3. **Easy Identification**: IP ranges clearly identify service types
4. **Migration-Friendly**: Designed to support service-to-LXC migration
5. **Operational Clarity**: Network troubleshooting simplified by predictable ranges

**Network Subnet**: 192.168.144.0/23
- **Static Services**: 192.168.144.0/24 (infrastructure and services)
- **DHCP Pool**: 192.168.145.0/24 (dynamic client assignments)

#### Core Infrastructure (192.168.144.1-19)
- **144.1**: Gateway (Fritz!Box router)
- **144.2-9**: Reserved for future routers/switches/infrastructure
- **144.10-19**: Physical hosts (Proxmox server, NAS, etc.)

#### Network Services (192.168.144.20-39)
- **144.20-24**: DNS/DHCP services (Pi-hole, secondary DNS)
- **144.25-29**: Monitoring services (status monitors, metrics)
- **144.31**: Caddy reverse proxy (for split DNS)
- **144.32**: Cloudflare Tunnel
- **144.30-34**: Network tools (VPN, tunnel services)
- **144.35-39**: Reserved for future network services

#### Database Services (192.168.144.40-59)
- **144.40-44**: SQL databases (PostgreSQL, MariaDB)
- **144.45-49**: NoSQL/Cache services (Redis, MongoDB, InfluxDB)
- **144.50-54**: Search/Analytics (Elasticsearch, TimescaleDB)
- **144.55-59**: Reserved for future database services

#### Application Services (192.168.144.60-99)
- **144.60-69**: Productivity applications (Planka, n8n, Nextcloud)
- **144.70-79**: Web/CMS applications (WordPress, static sites)
- **144.80-89**: Communication services (email, chat, collaboration)
- **144.90-99**: Reserved for future application services

#### Media & Entertainment (192.168.144.100-119)
- **144.100-109**: Media streaming (Plex, Jellyfin)
- **144.110-114**: Media management (Sonarr, Radarr, *arr stack)
- **144.115-119**: Reserved for future media services

#### Home Automation (192.168.144.120-139)
- **144.120-124**: Automation hubs (Home Assistant, OpenHAB)
- **144.125-129**: IoT controllers (Zigbee, Z-Wave hubs)
- **144.130-134**: Smart devices (sensors, switches)
- **144.135-139**: Reserved for future automation

#### Development & Testing (192.168.144.140-159)
- **144.140-149**: Development environments (dev instances, Git)
- **144.150-159**: Testing/staging (test instances, experiments)

#### Fixed Devices (192.168.144.160-199)
- **144.160-169**: Printers (3D printer, network printers)
- **144.170-179**: IoT devices (cameras, sensors, controllers)
- **144.180-189**: Network hardware (switches, APs, bridges)
- **144.190-199**: Reserved for future fixed devices

#### Management & Special (192.168.144.200-254)
- **144.200-209**: Management interfaces (IPMI, iDRAC, switch mgmt)
- **144.210-219**: Temporary services (migration hosts, testing)
- **144.220-229**: Backup services (backup targets, replication)
- **144.230-254**: Reserved for future expansion

**Operational Benefits:**
- **Service Identification**: IP address immediately indicates service category
- **Troubleshooting**: Network issues easier to diagnose with logical grouping
- **Security Planning**: Firewall rules organized by IP ranges
- **Capacity Planning**: Clear visibility into range utilization
- **Scalability**: Each category accommodates growth
- **Management Simplification**: DNS/monitoring patterns follow IP patterns

### DNS Configuration

**Pi-hole DNS Server** (192.168.144.20)
- **Primary DNS**: Pi-hole with ad blocking
- **Upstream DNS**: 1.1.1.1, 1.0.0.1, 8.8.8.8, 8.8.4.4  
- **DHCP Server**: Pi-hole provides DHCP for entire network
- **Local Domain**: .local suffix for internal hostname resolution

**Local Hostname Resolution:**

| Hostname | FQDN | IP Address | Service Type |
|----------|------|------------|--------------|
| server | server.local | 192.168.144.10 | Proxmox Host |
| pihole | pihole.local | 192.168.144.20 | DNS Service |
| monitor | monitor.local | 192.168.144.25 | Status Monitor |
| lanproxy | lanproxy.local | 192.168.144.31 | Caddy reverse proxy |
| tunnel | tunnel.local | 192.168.144.32 | Cloudflare Tunnel |
| postgresql | postgresql.local | 192.168.144.40 | Database |
| mariadb | mariadb.local | 192.168.144.41 | Database |  
| planka | planka.local | 192.168.144.60 | Project Management |
| n8n | n8n.local | 192.168.144.61 | Workflow Automation |
| wordpress | wordpress.local | 192.168.144.70 | WordPress JokeGoudriaan |
| kledingruil | kledingruil.local | 192.168.144.71 | WordPress Kledingruil |
| grav | grav.local | 192.168.144.72 | janvv Personal Website |
| plex | plex.local | 192.168.144.100 | Media Server |
| immich | immich.local | 192.168.144.110 | Media Server |
| homeassistant | homeassistant.local | 192.168.144.120 | Home Automation |

### Fixed IP Assignments

| Device | IP Address | MAC Address | Description | Lease Type |
|--------|------------|-------------|-------------|------------|
| 3D Printer | 192.168.144.160 | b8:f8:62:ed:f0:00 | 3D printer | Infinite |
| HP Printer | 192.168.144.161 | 84:69:93:cf:1f:ea | HP network printer | Infinite |

## Service Infrastructure

### Network Services
| Service | Container | IP | Hostname | Resources | Dependencies |
|---------|-----------|----|---------|-----------|--------------|
| Caddy reverse proxy | CT 109 | 192.168.144.31 | lanproxy.local | 1 CPU, 512MB RAM, 16GB | None |
| Cloudflare Tunnel | CT 107 | 192.168.144.32 | tunnel.local | 1 CPU, 512MB RAM, 8GB | None |

### Database Services

| Service | Container | IP | Hostname | Resources | Dependencies | Clients |
|---------|-----------|----|---------|-----------|--------------| --------|
| PostgreSQL | CT 100 | 192.168.144.40 | postgresql.local | 2 CPU, 2GB RAM, 16GB | None | Planka |
| MariaDB | CT 101 | 192.168.144.41 | mariadb.local | 2 CPU, 2GB RAM, 16GB | None | WordPress sites |

**MariaDB Databases**: wordpress (main site), wordpress_kledingruil (kledingruil site)

### Application Services

| Service | Container | IP | Hostname | Resources | Dependencies | External URL |
|---------|-----------|----|---------|-----------|--------------|-----------| 
| Planka | CT 103 | 192.168.144.60 | planka.local | 2 CPU, 2GB RAM, 16GB | PostgreSQL | https://tasks.janvv.nl |
| n8n | CT 106 | 192.168.144.61 | n8n.local | 2 CPU, 2GB RAM, 16GB | External APIs | https://n8n.janvv.nl |
| WordPress JokeGoudriaan | CT 104 | 192.168.144.70 | jokegoudriaan.local | 2 CPU, 2GB RAM, 16GB | MariaDB | https://jokegoudriaan.nl |
| WordPress Kledingruil | CT 105 | 192.168.144.71 | kledingruil.local | 2 CPU, 2GB RAM, 16GB | MariaDB | https://kledingruil.jokegoudriaan.nl |
| janvv Personal Website | CT 110 | 192.168.144.72 | grav.local | 2 CPU, 2GB RAM, 20GB | | https://opa.janvv.nl |

**Legacy Redirect**: https://jokegoudriaan.nl/kledingruil → https://kledingruil.jokegoudriaan.nl

### Media Services

| Service | Container | IP | Hostname | Resources | Dependencies | External URL |
|---------|-----------|----|---------|-----------|--------------|-----------| 
| Plex | CT 102 | 192.168.144.100 | plex.local | 4 CPU, 4GB RAM, 16GB | None | https://plex.janvv.nl |
| Immich | VM 108 | 192.168.144.110 | immich.local | 2 CPU, 4GB RAM, 64GB | None | https://photos.janvv.nl |

**Media Libraries**: Films, series, videos  
**Additional Storage**: `/media` → `/media` (media files)

### Home Automation

| Service | Container | IP | Hostname | Resources | Dependencies | External URL |
|---------|-----------|----|---------|-----------|--------------|-----------| 
| Home Assistant | VM 114 | 192.168.144.120 | homeassistant.local | 2 CPU, 8GB RAM, 32GB | None | https://homeassistant.janvv.nl |

**Note**: Home Assistant runs as appliance VM (Home Assistant OS), not LXC

## External Access Configuration

### Cloudflare Tunnel Routing

All external access uses a Cloudflare Tunnel — **no port forwarding is configured on the router**.

| Public Hostname             | Service                  | Backend (via lanproxy)        |
|-----------------------------|--------------------------|--------------------------------|
| assistant.janvv.nl          | Home Assistant           | 192.168.144.120:8123           |
| tasks.janvv.nl              | Planka                   | 192.168.144.60:1337            |
| pihole.janvv.nl             | Pi-hole                  | 192.168.144.20:80              |
| proxmox.janvv.nl            | Proxmox                  | 192.168.144.10:8006 (HTTPS)    |
| plex.janvv.nl               | Plex                     | 192.168.144.100:32400          |
| photos.janvv.nl             | Immich                   | 192.168.144.110:2283           |
| status.janvv.nl             | Status Monitor           | 192.168.144.25:80              |
| www.jokegoudriaan.nl        | WordPress JokeGoudriaan  | 192.168.144.70:80              |
| jokegoudriaan.nl            | WordPress JokeGoudriaan  | 192.168.144.70:80              |
| kledingruil.jokegoudriaan.nl| WordPress Kledingruil    | 192.168.144.71:80              |
| n8n.janvv.nl                | n8n                      | 192.168.144.61:5678            |
| opa.janvv.nl                | Grav                     | 192.168.144.72:80              |

**LAN optimization:**  
- On the LAN, all these hostnames resolve (via Pi-hole split-horizon DNS) to `192.168.144.31` (**lanproxy**).  
- The lanproxy Caddy service terminates TLS and forwards requests to the appropriate backend.  
- External traffic continues to be routed through Cloudflare Tunnel unchanged.

## Available Resources for New Services

### IP Range Utilization by Service Type

#### Database Services (192.168.144.40-59)
- **40**: PostgreSQL (✅ active)
- **41**: MariaDB (✅ active)  
- **42-59**: Available for Redis, MongoDB, InfluxDB, etc.

#### Application Services (192.168.144.60-99)  
- **60**: Planka (✅ active)
- **61**: n8n (✅ active)
- **62-69**: Available for productivity applications
- **70**: WordPress JokeGoudriaan (✅ active)
- **71**: WordPress kledingruil (✅ active)  
- **72**: janvv Personal Website (✅ active)  
- **73-99**: Available for web applications

#### Media Services (192.168.144.100-119)
- **100**: Plex (✅ active)
- **101-109**: Available for Jellyfin, streaming services
- **110**: Immich (✅ active)
- **111-119**: Available for media management (*arr stack, etc.)

#### Home Automation (192.168.144.120-139)
- **120**: Home Assistant (✅ active)  
- **121-139**: Available for IoT controllers, smart home services

## Backup and Monitoring

### Monitoring System

**Status Monitor**: Raspberry Pi 1B (192.168.144.25)
- **Coverage**: All active services monitored
- **Checks**: HTTP endpoints, database ports, system metrics
- **Dashboard**: https://status.janvv.nl
- **Update Frequency**: Service checks every minute, metrics every 2 minutes

**Service Health Coverage:**
- All 7 LXC services monitored for availability
- System metrics collected from all containers
- External access verification for public services

---

**Last Updated**: October 1, 2025
