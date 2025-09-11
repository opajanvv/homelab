# Home Assistant Deployment Guide

## VM Specifications

**VM Details:**
- **VM ID**: 114
- **IP Address**: 192.168.144.120
- **Memory**: 4 GB
- **CPU**: 2 cores
- **Disk**: 32 GB (nvme_pool)
- **OS**: Home Assistant OS (official appliance)

## Initial Setup

### VM Creation via Proxmox Helper Script

Use the Proxmox community helper script for Home Assistant OS:

```bash
# On Proxmox host (as root)
bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/vm/haos.sh)"
```

**Configuration during script:**
- **VM ID**: 114
- **Hostname**: homeassistant  
- **IP Address**: 192.168.144.120/23
- **Gateway**: 192.168.144.1
- **DNS**: 192.168.144.20 (Pi-hole)
- **Memory**: 4096 MB
- **CPU Cores**: 2
- **Disk Size**: 32 GB
- **Storage**: nvme_pool

### Network Configuration

**Static IP Configuration:**
- **IP Address**: 192.168.144.120
- **Subnet Mask**: 255.255.254.0 (/23)
- **Gateway**: 192.168.144.1
- **DNS Primary**: 192.168.144.20 (Pi-hole)
- **DNS Secondary**: 1.1.1.1 (Cloudflare)

### First Boot Setup

1. **Boot VM**: Start via Proxmox interface
2. **Wait for initialization**: First boot takes 5-10 minutes
3. **Access web interface**: http://192.168.144.120:8123
4. **Create account**: Set up initial admin user
5. **Configure location**: Set timezone and location data

## DNS Configuration

Add hostname resolution for network-wide access:

1. **SSH to Pi-hole server:**
   ```bash
   ssh jan@192.168.144.20
   ```

2. **Edit Pi-hole TOML configuration:**
   ```bash
   sudo nvim /opt/pihole/etc-pihole/pihole.toml
   ```

3. **Add hostname entry to hosts array:**
   ```
   "192.168.144.120 homeassistant.local homeassistant"
   ```

4. **Reload DNS configuration:**
   ```bash
   sudo podman exec pihole pihole reloaddns
   ```

5. **Test resolution:**
   ```bash
   nslookup homeassistant.local
   ssh homeassistant  # Should work from workstation
   ```

## External Access Configuration

### Cloudflare Tunnel Setup

**Route Configuration:**
- **Subdomain**: `assistant.janvv.nl`
- **Backend**: `http://192.168.144.120:8123`
- **Method**: Cloudflare Dashboard configuration

### Trusted Proxy Configuration

Home Assistant requires trusted proxy configuration for external access:

**File**: `/homeassistant/configuration.yaml`
```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 192.168.144.0/23  # Local network
    - 172.16.0.0/12     # Cloudflare tunnel ranges
    - 10.0.0.0/8        # Additional private ranges
```

**Apply configuration:**
1. **Developer Tools** → **YAML** → **Restart**
2. **Verify external access**: https://assistant.janvv.nl

## Access URLs

### Internal Access
- **Web Interface**: http://192.168.144.120:8123
- **Hostname**: http://homeassistant.local:8123

### External Access
- **Cloudflare URL**: https://assistant.janvv.nl

## Add-on Management

### Installing Add-ons

1. **Navigate to Settings** → **Add-ons**
2. **Browse Add-on Store**
3. **Install required add-ons**
4. **Configure via add-on interface**

**Essential Add-ons:**
- **File Editor**: Configuration editing via web interface
- **SSH & Web Terminal**: System access and troubleshooting
- **Samba Share**: File sharing access
- Various integration add-ons as needed

### Configuration Management

**Configuration Files:**
- Main config: `/homeassistant/configuration.yaml`
- Additional configs in `/homeassistant/` directory
- Edit via File Editor add-on or SSH

**Best Practices:**
- Create backups before configuration changes
- Test configuration changes in development environment
- Use Home Assistant configuration validation tools
- Document configuration changes with version information

## Verification Steps

### VM Status
```bash
# On Proxmox host
qm status 114
qm list | grep homeassistant
```

### Network Connectivity
```bash
# Test connectivity
ping 192.168.144.120

# Test web interface
curl -I http://192.168.144.120:8123

# Test hostname resolution
nslookup homeassistant.local
```

### Service Testing
```bash
# Test internal access
curl -I http://homeassistant.local:8123

# Test external access
curl -I https://assistant.janvv.nl
```

## Troubleshooting

### Common Issues

**VM Won't Start:**
- Check Proxmox VM settings and resource availability
- Verify disk integrity and storage pool status
- Ensure EFI disk is properly configured
- Check for conflicting VM IDs or MAC addresses

**Web Interface Inaccessible:**
- Verify VM is running: `qm status 114`
- Check network connectivity: `ping 192.168.144.120`
- Access VM console: `qm terminal 114`
- Verify Home Assistant service status via console

**External Access Issues:**
- Verify Cloudflare tunnel configuration and status
- Check trusted proxy settings in configuration.yaml
- Verify internal access works first
- Check Home Assistant logs for proxy errors

**Backup Restoration Issues:**
- **Version Mismatch**: "Backup was made on supervisor version X.X.X, can't restore on Y.Y.Y"
  - Solution: Use matching Home Assistant OS version
  - Alternative: Wait for supervisor updates (may not be available immediately)
- **Upload Failures**: Check backup file integrity and size limits
- **Partial Restoration**: Verify all required components are selected

### System Recovery

**From VM Snapshot:**
```bash
# List available snapshots
qm listsnapshot 114

# Restore from snapshot
qm rollback 114 [SNAPSHOT-NAME]
```

**From Home Assistant Backup:**
1. Create fresh Home Assistant OS VM with matching version
2. Boot VM and access initial setup
3. Choose "Upload backup" option instead of "CREATE MY SMART HOME"
4. Upload backup file and select components to restore
5. Wait for restoration process to complete (up to 45 minutes)
6. Verify all configurations and integrations are working

### Network Issues

**DNS Resolution Problems:**
- Verify Pi-hole is running and accessible
- Check VM network configuration matches requirements
- Test direct IP access vs hostname access
- Verify Pi-hole has correct hostname entry

**Gateway/Internet Issues:**
- Check VM can reach gateway: `ping 192.168.144.1`
- Verify internet connectivity: `ping 8.8.8.8`
- Check DNS servers in VM network configuration

## Maintenance

### Updates
- **Automatic Updates**: Home Assistant OS handles system updates
- **Supervisor Updates**: Applied through Home Assistant interface
- **Add-on Updates**: Managed through Add-on store interface

### Backups
- **Automatic Backups**: Configure in Settings → System → Backups
- **Manual Backups**: Create before major changes
- **External Backup**: Export backup files to external storage

### Monitoring
- **System Health**: Monitor via Settings → System → System Health
- **Log Files**: Access via Settings → System → Logs
- **Resource Usage**: Monitor CPU/Memory via System Information

---

**Home Assistant Status**: Active at 192.168.144.120  
**External Access**: https://assistant.janvv.nl  
**VM ID**: 114 on Proxmox host
