# Immich Photo Management Deployment Guide

## VM Specifications

**VM Details:**
- **VM ID**: 108
- **IP Address**: 192.168.144.110
- **Memory**: 4 GB
- **CPU**: 2 cores
- **Disk**: 64 GB (vms storage pool) - expanded from 32GB
- **OS**: Ubuntu 24.04.3 LTS Server

## Initial Setup

### VM Creation

Create Ubuntu VM for Immich using standard Proxmox commands:

```bash
# Create VM with Ubuntu ISO
qm create 108 --name immich --memory 4096 --cores 2 --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci --scsi0 vms:32 --ide2 iso:iso/ubuntu-24.04.3-live-server-amd64.iso,media=cdrom --boot order=ide2 --ostype l26

# Configure network and auto-start
qm set 108 --ipconfig0 ip=192.168.144.110/23,gw=192.168.144.1
qm set 108 --onboot 1
qm start 108
```

**VM Configuration:**
- **VM ID**: 108
- **Hostname**: immich
- **IP Address**: 192.168.144.110/23
- **Gateway**: 192.168.144.1
- **DNS Primary**: 192.168.144.20 (Pi-hole)
- **Memory**: 4096 MB
- **CPU Cores**: 2
- **Disk**: Initially 32GB, expanded to 64GB for photo storage

### Ubuntu Installation

Access VM console via Proxmox web interface for installation:

**Installation Configuration:**
- **OS**: Ubuntu Server (not minimized)
- **Network**: Configure static IP 192.168.144.110/23
  - Gateway: 192.168.144.1
  - DNS: 192.168.144.20 (Pi-hole)
  - Search domains: local
- **Storage**: Use entire disk, standard partitioning (not LVM)
- **User Account**: Create 'jan' user for consistency
- **SSH**: Enable OpenSSH server
- **Software**: Install minimal server packages

**Post-Installation:**
```bash
# Remove ISO and boot from disk
qm set 108 --ide2 none
qm set 108 --boot order=scsi0
qm reset 108
```

### Disk Expansion (If Needed)

If additional storage is needed for photos:

```bash
# Expand VM disk (run on Proxmox host)
qm resize 108 scsi0 +32G  # Expands from 32GB to 64GB

# Resize partition and filesystem (run in VM)
ssh immich
sudo parted /dev/sda
# In parted: resizepart 2 100%
# Then: quit
sudo resize2fs /dev/sda2
```

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
   "192.168.144.110 immich.local immich"
   ```

4. **Reload DNS configuration:**
   ```bash
   sudo podman restart pihole
   ```

5. **Test resolution:**
   ```bash
   nslookup immich.local
   ssh immich  # Should work from workstation
   ```

## Foundation Configuration

### Manual Foundation Setup

Due to VM deployment differences, foundation automation may require manual configuration:

```bash
# Install essential packages
sudo apt update
sudo apt install -y git ansible neovim htop curl wget ufw fail2ban

# Configure UFW firewall
sudo ufw --force enable
sudo ufw allow 22/tcp comment 'SSH access'
sudo ufw allow 2283/tcp comment 'Immich web interface'

# Add foundation automation cron job
echo "*/30 * * * * /usr/local/bin/provision-foundation > /dev/null 2>&1" | crontab -
```

### Foundation Automation (Alternative)

If foundation automation inventory includes 'immich' hostname:

```bash
# Install foundation automation prerequisites
sudo apt install -y git ansible
curl -o /tmp/provision-foundation https://gitlab.com/opajan/jansible-foundation/-/raw/main/scripts/provision.sh
sudo cp /tmp/provision-foundation /usr/local/bin/
sudo chmod +x /usr/local/bin/provision-foundation

# Run foundation automation
sudo ansible-pull -U https://gitlab.com/opajan/jansible-foundation.git playbooks/foundation.yml
```

**Note**: Foundation automation requires hostname 'immich' in jansible-foundation inventory.

## Immich Installation

### Docker Installation

```bash
# Install Docker and Docker Compose
sudo apt install -y docker.io docker-compose-v2

# Add user to docker group
sudo usermod -aG docker jan

# Log out and back in for group changes
exit
ssh jan@192.168.144.110
```

### Immich Deployment

```bash
# Create Immich directory
cd /home/jan
mkdir -p immich && cd immich

# Download official configuration
wget https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml
wget https://github.com/immich-app/immich/releases/latest/download/example.env
cp example.env .env
```

### Configuration

Edit environment file:
```bash
neovim .env
```

**Key Configuration Settings:**
```bash
# Database password (change from default)
DB_PASSWORD=immich_secure_password

# Upload location (dedicated directory with expanded space)
UPLOAD_LOCATION=/opt/immich/photos

# Database location (VM internal storage) 
DB_DATA_LOCATION=/home/jan/immich/postgres

# External URL (for mobile app access)
IMMICH_SERVER_URL=https://photos.janvv.nl
```

### Photo Storage Setup

Create the required directory structure:

```bash
# Create main photo storage directory
sudo mkdir -p /opt/immich/photos

# Create required Immich subdirectories
sudo mkdir -p /opt/immich/photos/{upload,thumbs,profile,encoded-video,backups,library}

# Create marker files that Immich expects
sudo touch /opt/immich/photos/upload/.immich
sudo touch /opt/immich/photos/thumbs/.immich
sudo touch /opt/immich/photos/profile/.immich
sudo touch /opt/immich/photos/encoded-video/.immich
sudo touch /opt/immich/photos/backups/.immich
sudo touch /opt/immich/photos/library/.immich

# Set proper ownership
sudo chown -R jan:jan /opt/immich/photos
```

### Start Services

```bash
# Create database directory
mkdir -p /home/jan/immich/postgres

# Start Immich services
docker compose up -d

# Verify services are running
docker compose ps
docker compose logs immich-server
```

## External Access Configuration

### Cloudflare Tunnel Setup

**Route Configuration:**
- **Subdomain**: `photos.janvv.nl`
- **Backend**: `http://192.168.144.110:2283`
- **Method**: Cloudflare Dashboard configuration

## Access URLs

### Internal Access
- **Web Interface**: http://192.168.144.110:2283
- **Hostname**: http://immich.local:2283

### External Access
- **Cloudflare URL**: https://photos.janvv.nl

## Initial Setup

### Web Interface Configuration

1. **Access Immich**: Navigate to https://photos.janvv.nl
2. **Click "Getting Started"**
3. **Create Admin Account**: Set up initial administrator user
4. **Configure Basic Settings**: Set timezone, language preferences
5. **Library Configuration**: Configure photo library settings

### Mobile App Setup

1. **Download Immich Mobile App**: Available for iOS and Android
2. **Server Configuration**: Use external URL `https://photos.janvv.nl`
3. **Login**: Use admin credentials created during web setup
4. **Auto-Backup Configuration**: Enable automatic photo/video backup
5. **Album Organization**: Configure albums and sharing settings

## Storage Management

### Current Storage Configuration

**Photo Storage**: `/opt/immich/photos` on VM's 64GB disk
- **Available Space**: ~46GB after OS and system files
- **Capacity**: Suitable for ~25GB photo collection with room for growth
- **Structure**: Proper Immich subdirectories with marker files

**Database Storage**: `/home/jan/immich/postgres` on same VM disk

**Storage Monitoring:**
```bash
# Check disk usage
df -h
du -sh /opt/immich/photos/

# Monitor growth
watch -n 60 'df -h'
```

### Backup Considerations

**VM Backup Strategy:**
- **VM Snapshots**: Daily Proxmox snapshots include complete system state
- **Photo Data**: All photos included in VM snapshots
- **Configuration**: Docker Compose files included in snapshots

**Manual Backup Commands:**
```bash
# Backup configuration
cp /home/jan/immich/.env /home/jan/immich-backup-$(date +%Y%m%d).env

# Export database (if needed)
docker compose exec database pg_dump -U postgres immich > /home/jan/immich-db-backup-$(date +%Y%m%d).sql
```

## Service Management

### Docker Compose Commands

```bash
# View service status
docker compose ps

# View logs
docker compose logs
docker compose logs immich-server

# Restart services
docker compose restart

# Stop services
docker compose down

# Update to latest version
docker compose pull
docker compose up -d
```

### System Commands

```bash
# Check system resources
htop
df -h

# Check service ports
sudo netstat -tlnp | grep 2283

# Monitor logs
docker compose logs -f immich-server
```

## Verification Steps

### Service Testing
```bash
# Test local web interface
curl -I http://localhost:2283

# Test network access
curl -I http://immich.local:2283

# Test external access
curl -I https://photos.janvv.nl
```

### Mobile App Testing
- Install Immich mobile app
- Configure server: https://photos.janvv.nl
- Test photo upload and sync
- Verify automatic backup functionality

## Troubleshooting

### Common Issues

**VM Won't Start:**
- Check VM configuration: `qm config 108`
- Verify disk space on vms storage pool
- Check VM status: `qm status 108`

**Network Connectivity Issues:**
- Verify static IP configuration in VM
- Test DNS resolution: `nslookup immich.local`
- Check Pi-hole configuration for hostname entry
- Verify Cloudflare tunnel routing

**Docker Services Not Starting:**
- Check disk space: `df -h`
- Verify Docker daemon: `sudo systemctl status docker`
- Check service logs: `docker compose logs`
- Verify user group membership: `groups jan`

**Photo Storage Issues:**
- Verify directory structure: `ls -la /opt/immich/photos/`
- Check marker files exist: `ls -la /opt/immich/photos/*/.immich`
- Verify ownership: `ls -la /opt/immich/photos/`
- Check container mounts: `docker inspect immich_server | grep -A5 "Mounts"`

**Web Interface Inaccessible:**
- Check service status: `docker compose ps`
- Verify port binding: `sudo netstat -tlnp | grep 2283`
- Check UFW firewall: `sudo ufw status`
- Test local connectivity: `curl -I http://localhost:2283`

**Mobile App Connection Issues:**
- Verify external URL is accessible: `curl -I https://photos.janvv.nl`
- Check Cloudflare tunnel configuration
- Verify SSL certificate validity
- Test from external network (mobile data)

**Directory Structure Errors:**
If Immich fails with "Failed to read .immich" errors:
```bash
# Stop services
docker compose down

# Recreate directory structure
sudo mkdir -p /opt/immich/photos/{upload,thumbs,profile,encoded-video,backups,library}
sudo touch /opt/immich/photos/{upload,thumbs,profile,encoded-video,backups,library}/.immich
sudo chown -R jan:jan /opt/immich/photos

# Restart services
docker compose up -d
```

### Performance Issues

**Slow Photo Processing:**
- Monitor CPU usage: `htop`
- Check available memory: `free -h`
- Consider increasing VM resources
- Monitor disk I/O with `iotop`

**Database Performance:**
- Check PostgreSQL logs: `docker compose logs database`
- Monitor database connections
- Consider database maintenance commands

**Disk Space Issues:**
- Monitor photo storage growth: `du -sh /opt/immich/photos/`
- Consider expanding VM disk if needed
- Clean up old database backups and logs

## Maintenance

### Updates

**Immich Updates:**
```bash
cd /home/jan/immich
docker compose pull
docker compose up -d
```

**System Updates:**
```bash
sudo apt update && sudo apt upgrade
```

### Monitoring

**Service Health:**
- Monitor via web interface dashboard
- Check Docker service status regularly
- Monitor disk space growth
- Verify external access functionality

**Log Management:**
```bash
# View recent logs
docker compose logs --tail=50 immich-server

# Monitor live logs
docker compose logs -f
```

**Capacity Planning:**
- Monitor photo collection growth
- Plan for disk expansion when approaching 80% capacity
- Consider implementing automated cleanup of thumbnails/cache

---

**Immich Status**: Active at 192.168.144.110  
**External Access**: https://photos.janvv.nl  
**VM ID**: 108 on Proxmox host  
**Storage**: 64GB VM disk with photos at `/opt/immich/photos`  
**Purpose**: Self-hosted Google Photos replacement with automatic mobile sync
