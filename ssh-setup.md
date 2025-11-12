# SSH Setup and Configuration Guide

## Overview

This guide documents SSH configuration and access patterns for the homelab infrastructure. SSH access follows a security-first approach with key-based authentication and network restrictions.

## SSH Security Architecture

### Jump Box Pattern

All LXC container SSH access is restricted to the Proxmox host only. This eliminates direct network SSH exposure while maintaining operational simplicity.

**Design Principles:**
- **LXC Containers**: SSH access allowed only from Proxmox host (192.168.144.10)
- **External Access**: Use ProxyJump through Proxmox host
- **No Port Forwarding**: SSH is not exposed to external networks
- **Key-Only Authentication**: Password authentication disabled

### Network Security Model

**SSH Access Rules:**
- **Proxmox Host** (192.168.144.10): Direct SSH access from network
- **LXC Containers**: SSH allowed only from 192.168.144.10
- **Physical Devices** (Raspberry Pi): SSH allowed only from 192.168.144.10
- **External Access**: Via ProxyJump through Proxmox host

**Firewall Configuration:**
```bash
# Standard firewall rule for all containers/devices
ufw allow from 192.168.144.10 to any port 22 proto tcp comment 'SSH from Proxmox jumpbox only'
```

## Automatic SSH Setup (Foundation Automation)

### For LXC Containers

Foundation automation handles SSH configuration automatically for all LXC containers. This is the preferred method for new deployments.

**What Foundation Automation Configures:**
- Creates `jan` user with sudo access
- Deploys SSH keys (public and private)
- Configures SSH key-only authentication
- Hardens SSH configuration (disables password auth, root login)
- Sets up fail2ban for intrusion prevention
- Configures UFW firewall with SSH restrictions

**Prerequisites:**
1. Container must be added to jansible-foundation inventory
2. Vault file must be available at `/etc/.vault.txt` on Proxmox host

**Execution:**
```bash
# Copy vault file to container
pct push <ID> /etc/.vault.txt /etc/.vault.txt

# Run foundation automation
pct exec <ID> -- ansible-pull -U https://gitlab.com/opajan/jansible-foundation.git playbooks/foundation.yml

# Add automated cron job
pct exec <ID> -- bash -c 'echo "*/30 * * * * /usr/local/bin/provision-foundation > /dev/null 2>&1" | crontab -'
```

**Verification:**
```bash
# Check if jan user exists
pct exec <ID> -- id jan

# Verify SSH configuration
pct exec <ID> -- grep -E "^(PermitRootLogin|PasswordAuthentication)" /etc/ssh/sshd_config

# Check firewall rules
pct exec <ID> -- ufw status | grep 22
```

*For complete foundation automation details, see `foundation-automation.md`.*

## Manual SSH Setup

### For Devices That Cannot Use Foundation Automation

Some devices (e.g., slow Raspberry Pi models, VMs with appliance OS) require manual SSH configuration.

#### Step 1: User Creation

```bash
# Create jan user with sudo access
sudo useradd -m -s /bin/bash -G sudo jan
echo "jan ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/jan

# Set temporary password for initial setup (if needed)
sudo passwd jan
```

#### Step 2: SSH Directory Setup

```bash
# Create SSH directory with proper permissions
sudo mkdir -p /home/jan/.ssh
sudo chmod 700 /home/jan/.ssh
sudo chown jan:jan /home/jan/.ssh
```

#### Step 3: Deploy SSH Keys

**From your workstation:**
```bash
# Copy SSH public key to device
ssh-copy-id jan@<DEVICE_IP>

# Or manually copy key
cat ~/.ssh/id_rsa.pub | ssh jan@<DEVICE_IP> "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

**Verify key deployment:**
```bash
# Test SSH key authentication
ssh jan@<DEVICE_IP>
# Should connect without password prompt
```

#### Step 4: SSH Hardening

```bash
# Edit SSH configuration
sudo nano /etc/ssh/sshd_config
```

**Required SSH Configuration Changes:**
```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

**Apply changes:**
```bash
# Test SSH configuration
sudo sshd -t

# Restart SSH service
sudo systemctl restart ssh
sudo systemctl status ssh
```

#### Step 5: Firewall Configuration

```bash
# Enable UFW firewall
sudo ufw --force enable

# Allow SSH only from Proxmox host
sudo ufw allow from 192.168.144.10 to any port 22 proto tcp comment 'SSH from Proxmox jumpbox only'

# Verify firewall rules
sudo ufw status verbose
```

#### Step 6: Install fail2ban (Optional but Recommended)

```bash
# Install fail2ban
sudo apt update
sudo apt install -y fail2ban

# Enable and start service
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Verify status
sudo fail2ban-client status sshd
```

## SSH Access Patterns

### Accessing LXC Containers

**From Proxmox Host:**
```bash
# Direct SSH access (from Proxmox host only)
ssh jan@<container-hostname>
# or
ssh jan@<container-ip>
```

**From Workstation (External):**

Always explicitly specify the jump box using ProxyJump:
```bash
# Use ProxyJump explicitly
ssh -J server <container-hostname>
# or
ssh -J jan@192.168.144.10 jan@<container-hostname>
```

**Examples:**
```bash
ssh -J server planka.local
ssh -J server postgresql.local
ssh -J server homeassistant.local
```

**Key Management:** Your laptop's SSH public key only needs to be on the jump box (server). The jump box's SSH key is deployed to all target machines via foundation automation. No agent forwarding (`-A`) is needed—the jump box authenticates to targets using its own key.

**Security Benefit:** By requiring explicit ProxyJump in commands, the jump box pattern is not stored in SSH config files. If your workstation is compromised, an attacker would need to know about the jump box pattern rather than discovering it automatically.

### Accessing Physical Devices

**From Proxmox Host:**
```bash
# Direct SSH access
ssh jan@192.168.144.20  # Pi-hole
ssh jan@192.168.144.25  # Monitor
```

**From Workstation (External):**
```bash
# Use explicit ProxyJump (recommended for security)
ssh -J server jan@192.168.144.20
ssh -J server jan@192.168.144.25
```

### Accessing Proxmox Host

**From Network:**
```bash
ssh jan@192.168.144.10
# or
ssh server
```

**From External Network:**
- Proxmox web interface accessible via Cloudflare tunnel at https://proxmox.janvv.nl
- SSH access should be configured via VPN or secure tunnel if needed externally

## SSH Key Management

### Key Deployment

SSH keys are managed through foundation automation for LXC containers. For manual deployments:

**Public Key Location:**
- User's authorized_keys: `~/.ssh/authorized_keys`
- Permissions: `600` for authorized_keys, `700` for .ssh directory

**Key Rotation:**
1. Generate new key pair on workstation
2. Add new public key to authorized_keys
3. Test new key authentication
4. Remove old key from authorized_keys
5. Update foundation automation vault if applicable

### Multiple Key Support

Multiple SSH keys can be added to `~/.ssh/authorized_keys` (one per line). Foundation automation deploys keys from the vault.

## Troubleshooting

### Cannot Connect to Container

**Check 1: Verify Container is Running**
```bash
# On Proxmox host
pct status <ID>
pct list
```

**Check 2: Verify Network Connectivity**
```bash
# Ping container
ping <container-ip>

# Check if SSH port is open
nc -zv <container-ip> 22
```

**Check 3: Verify Firewall Rules**
```bash
# Check UFW status on container
pct exec <ID> -- ufw status | grep 22

# Verify rule allows Proxmox host
pct exec <ID> -- ufw status verbose
```

**Check 4: Verify SSH Service**
```bash
# Check SSH service status
pct exec <ID> -- systemctl status ssh

# Check SSH configuration
pct exec <ID> -- sshd -t
```

### Authentication Failures

**Check 1: Verify SSH Key**
```bash
# Test key authentication
ssh -v jan@<hostname>
# Look for "Authentications that can continue: publickey"

# Verify key is in authorized_keys
ssh jan@<hostname> "cat ~/.ssh/authorized_keys"
```

**Check 2: Check File Permissions**
```bash
# On target device
ls -la ~/.ssh/
# Should show:
# drwx------ .ssh
# -rw------- authorized_keys
```

**Check 3: Check SSH Configuration**
```bash
# Verify PasswordAuthentication is disabled
grep PasswordAuthentication /etc/ssh/sshd_config
# Should show: PasswordAuthentication no
```

### Firewall Blocking Access

**Check UFW Rules:**
```bash
# View all firewall rules
ufw status verbose

# Check if SSH rule exists
ufw status | grep 22

# If missing, add rule
ufw allow from 192.168.144.10 to any port 22 proto tcp comment 'SSH from Proxmox jumpbox only'
```

**Check fail2ban:**
```bash
# Check if IP is banned
sudo fail2ban-client status sshd

# Unban IP if needed
sudo fail2ban-client set sshd unbanip <IP_ADDRESS>
```

### DNS Resolution Issues

**Check Hostname Resolution:**
```bash
# Test DNS resolution
nslookup <hostname>.local
dig <hostname>.local

# Check Pi-hole configuration
ssh jan@192.168.144.20
sudo cat /opt/pihole/etc-pihole/pihole.toml | grep <hostname>
```

**Use IP Address Directly:**
If hostname resolution fails, use IP address:
```bash
ssh -J server jan@192.168.144.40  # postgresql
```

## Security Best Practices

### Current Implementation

✅ **Key-only authentication** - No password authentication  
✅ **Root login disabled** - Only user accounts can SSH  
✅ **Network restrictions** - SSH only from Proxmox host  
✅ **fail2ban protection** - Automatic IP banning for failed attempts  
✅ **UFW firewall** - Explicit allow rules only  
✅ **Regular updates** - Automated security updates via foundation automation  

### Additional Recommendations

- **Explicit ProxyJump usage** - Always use `-J server` explicitly in commands (not in SSH config) to keep jump box pattern less obvious if workstation is compromised
- **Regular key rotation** - Rotate SSH keys periodically
- **Monitor SSH logs** - Review `/var/log/auth.log` for suspicious activity
- **Use strong key algorithms** - Prefer Ed25519 or RSA 4096-bit keys
- **Limit user access** - Only grant SSH access to necessary users
- **Audit authorized_keys** - Regularly review who has access

## Related Documentation

- **Foundation Automation**: `foundation-automation.md` - Automatic SSH setup for LXC containers
- **LXC Deployment Guide**: `lxc-deployment-guide.md` - Container deployment procedures
- **Architecture Principles**: `architecture-principles.md` - SSH security architecture overview
- **Infrastructure Catalog**: `infrastructure-catalog.md` - IP addresses and hostnames

---

**Last Updated**: [Date will be updated when instructions are added]

