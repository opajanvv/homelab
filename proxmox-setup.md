# Proxmox Setup

## Storage Configuration

### Physical Disks
- **2x NVMe 1TB**: nvme_pool (mirror) - 928GB usable
- **2x SSD 4TB**: ssd_pool (mirror) - 3.62TB usable  
- **2x HDD 2TB**: media_pool (mirror) - 1.81TB usable
- **1x HDD 1TB**: backup_pool (single) - 928GB usable
- **1x SSD 250GB**: rpool (system) - 230GB usable

### Storage Allocation
- **nvme_pool**: VM disks (fast storage)
- **ssd_pool**: Container data, VM data, databases
- **media_pool**: Media files, large storage
- **backup_pool**: Backups, ISO images
- **rpool**: Proxmox system

### Proxmox Storage Mapping
- **vms** → nvme_pool/vms (VM disk images)
- **cts** → nvme_pool/cts (container storage)
- **backups** → backup_pool/backups
- **iso** → backup_pool/iso  
- **templates** → backup_pool/templates

## Network Configuration

### Proxmox Network Bridge
- **Bridge**: vmbr0 (connected to physical network interface)
- **Gateway**: 192.168.144.1
- **Subnet**: 192.168.144.0/23

**For complete network topology, IP assignments, DNS/DHCP configuration, and troubleshooting procedures, see `network-overview.md`.**

### Basic Proxmox Host Network
- **Proxmox Host IP**: 192.168.144.10
- **Hostname**: server.local
- **DNS**: 192.168.144.20 (Pi-hole)

**Host DNS Configuration** (`/etc/resolv.conf`):
```
search local
nameserver 192.168.144.20
nameserver 1.1.1.1
```

## Service Deployment Workflow

### For Service-per-LXC Architecture

**Step 1: Determine Service Type and IP Range**
- **Database services**: 192.168.144.40-59 (PostgreSQL, MariaDB, Redis)
- **Application services**: 192.168.144.60-79 (web apps, APIs)
- **Media services**: 192.168.144.100-119 (Plex, streaming)
- **Development/testing**: 192.168.144.140-159

*For complete IP allocation strategy, see `network-overview.md`.*

**Step 2: Deploy Service**
1. **Clone from Ubuntu template** (CT 901) - Ubuntu 24.04 LTS with foundation automation pre-configured
2. **Configure LXC resources** - Assign appropriate CPU/RAM based on service requirements
3. **Assign static IP** from appropriate service range
4. **Configure persistent storage** - Mount `/lxcdata/<service>` for data persistence and backup coverage
5. **Manual service installation** - Use standard package managers (apt, snap, etc.)
6. **Service-specific configuration** - Configure service to use persistent storage paths

**Step 3: Network Integration**
1. **Add DNS entry** to Pi-hole configuration
2. **Configure firewall** rules if needed
3. **Test connectivity** and hostname resolution

*For detailed DNS integration procedures, see `network-overview.md`.*

**Step 4: Documentation**
1. **Create deployment guide** for the service
2. **Update service catalog** with new service details
3. **Document configuration choices** made during installation

### Adding DNS Entries for New Services

**Quick Reference:**
```bash
# SSH to Pi-hole
ssh jan@192.168.144.20

# Edit configuration
sudo nvim /opt/pihole/etc-pihole/pihole.toml

# Add to hosts array under [dns]:
"IP_ADDRESS hostname.local hostname"

# Reload configuration
sudo podman exec pihole pihole reloaddns

# Test resolution
nslookup hostname.local
```

*For complete Pi-hole configuration details, see `pihole.md` and `network-overview.md`.*

## VM Deployment for Appliance Services

### When to Use VMs Instead of LXC

Use VM deployment for services that:
- Require dedicated appliance OS (Home Assistant OS, pfSense, etc.)
- Need complete hardware isolation
- Have complex system-level requirements
- Are distributed as complete OS images

### Standard VM Creation Process

1. **Download appliance image** or use Proxmox community script if available
2. **Create VM** with appropriate resources for the appliance
3. **Configure networking** with static IP from appropriate range
4. **Initial appliance setup** following vendor documentation
5. **Network integration** - DNS entries and firewall rules
6. **External access** via Cloudflare tunnel if needed

## Future Expansion

### Scaling Considerations
- **Service-per-LXC**: Each service gets dedicated LXC container
- **Resource planning**: Ensure adequate CPU/RAM/storage per service
- **IP range management**: Use systematic allocation by service type

### New Service Integration
- **Template-based deployment**: Clone from CT 901 for consistent base
- **Manual installation approach**: Standard package management for reliability
- **IP assignment**: Assign from appropriate range based on service type
- **Network planning**: DNS and firewall configuration
- **Documentation**: Update guides and service catalog

---

*This Proxmox setup provides the foundation for a scalable service-per-LXC infrastructure. All configuration follows established patterns for consistency and maintainability.*
