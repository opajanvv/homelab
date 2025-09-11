# Pi 1B Status Monitor Deployment Guide

## Prerequisites

- Raspberry Pi 1B with DietPi OS installed
- Network connectivity to homelab (192.168.144.0/24)
- Static IP assignment: 192.168.144.26
- Hostname: pi2

## Manual Foundation Setup

**Note**: The Pi 1B is too slow for full foundation automation. Use this manual approach instead.

### User Management

```bash
# Create jan user with sudo access
sudo useradd -m -s /bin/bash -G sudo jan
echo "jan ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/jan

# Set password for initial SSH setup
sudo passwd jan

# Create SSH directory
sudo mkdir -p /home/jan/.ssh
sudo chmod 700 /home/jan/.ssh
sudo chown jan:jan /home/jan/.ssh

# From main machine, copy SSH key
ssh-copy-id jan@192.168.144.26
```

### System Configuration

```bash
# Set timezone
sudo ln -sf /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime
echo "Europe/Amsterdam" | sudo tee /etc/timezone

# Enable NTP synchronization
sudo systemctl enable systemd-timesyncd
sudo systemctl start systemd-timesyncd

# Verify time sync
sudo systemctl status systemd-timesyncd
date
```

### Security Hardening

```bash
# Remove default DietPi user
sudo userdel -r dietpi

# Edit SSH configuration
sudo nano /etc/ssh/sshd_config
```

**SSH Configuration Changes:**
```
PermitRootLogin no
PasswordAuthentication no
```

```bash
# Restart SSH service
sudo systemctl restart ssh
sudo systemctl status ssh
```

### Package Installation

```bash
# Fix terminal support
# Install midnight Commander
# Install Neovim
# Install web server
# Combine in one command, because apt install is quite slow on this Pi
sudo apt update && sudo apt install nginx neovim mc ncurses-term -y

# Verify nginx is running
sudo systemctl status nginx
```

## Status Monitor Service Deployment

### Repository Setup

```bash
# Clone the monitor services repository
sudo -i
cd /root
git clone https://gitlab.com/opajan/monitor-services.git
cd /root/monitor-services

# Set up directory structure
sudo mkdir -p /usr/local/bin
sudo mkdir -p /var/www/html
```

### Script Installation

```bash
# Install monitoring scripts
sudo cp monitor-services/monitor/* /usr/local/bin/
sudo chmod +x /usr/local/bin/check-services.sh
sudo chmod +x /usr/local/bin/collect-metrics.sh

# Install web interface
sudo cp monitor-services/www/index.html /var/www/html/index.html
sudo chown www-data:www-data /var/www/html/index.html
```

### Cron Job Configuration

```bash
# Edit crontab for monitoring jobs
crontab -e
```

**Add these cron entries:**
```
# Service status check - every minute
* * * * * /usr/local/bin/check-services.sh

# System metrics collection - every minute  
*/2 * * * * /usr/local/bin/collect-metrics.sh

# Refresh website when repository is updated
*/30 * * * * /root/monitor-services/update.sh
```

### Additional Package Requirements

```bash
# Install netcat for MariaDB connectivity testing
sudo apt install netcat-openbsd -y

# Install curl for HTTP service testing (should already be installed)
which curl || sudo apt install curl -y
```

## DNS Configuration

Add hostname resolution for network-wide access:

1. **SSH to Pi-hole server:**
   ```bash
   ssh jan@192.168.144.25
   ```

2. **Edit Pi-hole TOML configuration:**
   ```bash
   sudo nvim /opt/pihole/etc-pihole/pihole.toml
   ```

3. **Add hostname entry to hosts array:**
   ```
   "192.168.144.26 monitor.local monitor"
   ```

4. **Reload DNS configuration:**
   ```bash
   sudo podman exec pihole pihole reloaddns
   ```

5. **Test resolution:**
   ```bash
   nslookup monitor.local
   ssh monitor  # Test from workstation
   ```

## External Access Configuration

### Cloudflare Tunnel Setup

**Route Configuration:**
- **Subdomain**: `status.janvv.nl`
- **Backend**: `http://192.168.144.26`
- **Method**: Cloudflare Dashboard configuration

### Access URLs

- **External**: https://status.janvv.nl
- **Internal**: http://192.168.144.26 or http://monitor

## Verification Steps

### Service Status
```bash
# Check nginx is running
sudo systemctl status nginx

# Check cron jobs are configured
crontab -l

# Check monitoring scripts exist and are executable
ls -la /usr/local/bin/check-services.sh
ls -la /usr/local/bin/collect-metrics.sh
```

### Monitoring Function Testing
```bash
# Test service monitoring script manually
/usr/local/bin/check-services.sh

# Check JSON output was created
ls -la /var/www/html/services-status.json
cat /var/www/html/services-status.json

# Test metrics collection script manually
/usr/local/bin/collect-metrics.sh

# Check JSON output was created
ls -la /var/www/html/system-metrics.json
cat /var/www/html/system-metrics.json
```

### Web Interface Testing
```bash
# Test local web access
curl -I http://localhost/

# Test network access (by IP)
curl -I http://192.168.144.26/

# Test hostname resolution
curl -I http://monitor/
```

### External Access
- Visit: https://status.janvv.nl
- Should load status monitor dashboard with service and system metrics
- Page should auto-refresh every 30 seconds

## Troubleshooting

### Common Issues

**Nginx won't start:**
- Check if another web server is running: `sudo netstat -tlnp | grep :80`
- Verify nginx configuration: `sudo nginx -t`
- Check system logs: `sudo journalctl -u nginx`

**Monitoring scripts not running:**
- Check cron service is running: `sudo systemctl status cron`
- Verify cron jobs are configured: `crontab -l`
- Check script permissions: `ls -la /usr/local/bin/check-services.sh`
- Test scripts manually: `/usr/local/bin/check-services.sh`

**JSON files not generated:**
- Check script execution permissions
- Verify web directory permissions: `ls -la /var/www/html/`
- Check disk space: `df -h`
- Review script output for errors

**External access fails:**
- Verify nginx allows external connections
- Check Cloudflare tunnel configuration
- Test local access first
- Verify DNS resolution: `nslookup monitor.local`

**Services showing as down incorrectly:**
- Verify network connectivity to monitored hosts
- Check if Node Exporter is running on target hosts: `curl http://192.168.144.10:9100/metrics`
- Test individual service URLs manually
- Check timeout values in scripts are appropriate for Pi 1B performance

**Hostname resolution fails:**
- Verify DNS configuration in Pi-hole TOML
- Test direct IP access first: `curl http://192.168.144.26`
- Check Pi-hole is resolving: `nslookup monitor 192.168.144.25`

### Log Locations
- **Nginx logs**: `/var/log/nginx/access.log` and `/var/log/nginx/error.log`
- **Cron logs**: `sudo journalctl -u cron`
- **System logs**: `sudo journalctl -n 50`

### Performance Considerations
- **Pi 1B is slow**: Scripts may take longer to execute than on modern hardware
- **Timeout adjustments**: Consider increasing timeout values in scripts if services appear down incorrectly
- **Monitoring frequency**: 1-minute intervals may be aggressive; consider 2-5 minute intervals if performance issues occur

## Maintenance

### Service Management
```bash
# Check nginx status
sudo systemctl status nginx

# Restart nginx if needed
sudo systemctl restart nginx

# View recent cron execution
sudo journalctl -u cron -f
```

### Script Updates
```bash
# Update monitoring scripts from repository
/usr/local/bin/update-monitor.sh

# Or manually:
cd /home/jan/monitor-services
git pull
sudo cp www/index.html /var/www/html/index.html
sudo cp monitor/* /usr/local/bin/
```

### Adding New Monitored Services

**To add a new service to monitoring:**

1. **Edit check-services.sh:**
   ```bash
   sudo nvim /usr/local/bin/check-services.sh
   ```

2. **Add service to SERVICES array:**
   ```bash
   "ServiceName:IP:PORT:PATH"
   ```

3. **Edit collect-metrics.sh for new hosts:**
   ```bash
   sudo nvim /usr/local/bin/collect-metrics.sh
   ```

4. **Add host to HOSTS array:**
   ```bash
   "hostname:IP"
   ```

5. **Test changes:**
   ```bash
   /usr/local/bin/check-services.sh
   /usr/local/bin/collect-metrics.sh
   ```

### Backup Considerations
- **Configuration**: Scripts and cron jobs (documented in this guide)
- **Web content**: `/var/www/html/` (recreatable from repository)
- **System**: Standard Pi backup procedures
- **Repository**: Git repository provides version control for monitoring scripts

### System Monitoring
- **Resource usage**: Pi 1B has limited resources; monitor CPU and memory usage
- **Disk space**: Monitor `/var/log/` and `/var/www/html/` for log file growth
- **Network connectivity**: Monitor Pi's network connection to homelab services

## Security Considerations

### Network Security
- **Internal access only**: Monitor interface accessible on internal network
- **External access**: Only via Cloudflare tunnel (SSL terminated by Cloudflare)
- **No authentication**: Status page is read-only monitoring information
- **Firewall**: Default DietPi firewall configuration adequate

### Data Privacy
- **Service status only**: No sensitive service data collected or displayed
- **System metrics**: Basic system performance data only
- **No logging**: No access logs or user tracking implemented
- **Public status**: External status page shows only service availability

---

*This deployment guide provides a lightweight monitoring solution for the Pi 1B, following simplified patterns appropriate for the hardware limitations while maintaining consistency with homelab documentation standards.*
