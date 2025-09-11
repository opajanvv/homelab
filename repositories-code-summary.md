# Repository Code Summaries

## Foundation Automation Repository
**URL**: `https://gitlab.com/opajan/jansible-foundation.git`

**Structure**:
```
├── playbooks/foundation.yml          # Main Ansible playbook
├── roles/
│   ├── users/         # User management (jan user, SSH keys, cleanup)
│   ├── system/        # Hostname, timezone, locale, MOTD
│   ├── security/      # SSH hardening, UFW, fail2ban, unattended-upgrades
│   ├── utilities/     # Essential packages (nvim, git, zsh, oh-my-zsh)
│   ├── dotfiles/      # Personal dotfiles deployment via stow
│   └── monitoring/    # Prometheus Node Exporter, health checks, log rotation
├── scripts/provision.sh             # Wrapper script with error handling
├── inventory/hosts                  # LXC container hostnames
└── secrets/users.yml               # Ansible Vault encrypted user data
```

**Key Functionality**:
- **User Management**: Creates `jan` user with sudo, SSH keys, zsh shell
- **Security**: SSH key-only auth, fail2ban, UFW deny-by-default, automatic updates  
- **Development Environment**: nvim, git, modern CLI tools, oh-my-zsh
- **Monitoring**: Node Exporter on port 9100, basic health checks
- **Personal Environment**: GitLab OAuth dotfiles with 30-minute updates

**Automation Schedule**: 
- Foundation: Every 30 minutes via cron
- Dotfiles: Every 30 minutes per user via cron

**Critical Files**:
- `/etc/.vault.txt` - Required for encrypted variables
- `/usr/local/bin/provision-foundation` - Provision script
- `/var/log/jansible-foundation.log` - Execution logs

## Proxmox Host Repository
**URL**: `https://gitlab.com/opajan/jansible-proxmox.git`

**Structure**:
```
├── playbooks/proxmox.yml           # Main Proxmox configuration
├── roles/proxmox/                  # Proxmox-specific configuration
├── scripts/provision.sh            # Proxmox provision wrapper
└── inventory/hosts                 # Proxmox hosts
```

**Key Functionality**:
- Proxmox post-install configuration
- No-subscription repository management
- ZFS configuration and tuning
- Version detection (PVE 8/9 compatibility)

**Automation Schedule**: Every 15 minutes on Proxmox host

## Monitor Services Repository
**URL**: `https://gitlab.com/opajan/monitor-services.git`

**Structure**:
```
├── monitor/
│   ├── check-services.sh          # Service health checker
│   └── collect-metrics.sh         # System metrics collector
├── www/index.html                 # Status dashboard
└── update.sh                      # Repository update script
```

**Key Functionality**:

**Service Monitoring** (`check-services.sh`):
- Tests HTTP endpoints with curl (10s timeout)
- Tests database ports with netcat (5s timeout)  
- Outputs JSON to `/var/www/html/services-status.json`
- Configurable service array for HTTP and database services

**System Metrics** (`collect-metrics.sh`):
- Queries Node Exporter on port 9100 (10s timeout)
- Extracts load, memory, disk metrics from Prometheus format
- Outputs JSON to `/var/www/html/system-metrics.json`
- Configurable host array for system monitoring

**Web Dashboard**:
- Auto-refreshing status page (30s intervals)
- Service status cards with up/down indicators
- System metrics with progress bars and color coding
- External access via configured Cloudflare tunnel

**Automation Schedule**: 
- Service checks: Every minute
- Metrics collection: Every 2 minutes  
- Repository updates: Every 30 minutes

## Operational Context

**Foundation Automation**:
- Must add new hostnames to `inventory/hosts` before first run
- Requires `/etc/.vault.txt` file for encrypted user data
- Self-healing: Cleans cache and retries on Git repository errors

**Monitor Services**:
- Deployed on dedicated monitoring host with performance considerations
- JSON files serve live data to web dashboard
- Extensible: Add services to arrays in scripts

**Integration Points**:
- All LXC containers run Node Exporter (foundation automation)
- Pi-hole provides DNS resolution for service hostnames
- Cloudflare tunnel provides external access without port forwarding
- Status monitoring requires service hostnames in Pi-hole configuration

**Key Patterns**:
- **Pull-based automation**: Containers fetch configs from GitLab
- **Ansible-pull optimization**: Uses `-o` flag for performance
- **Error handling**: Automatic cache cleanup and retry logic
- **Monitoring data flow**: Scripts → JSON → Web dashboard → External access
