# Foundation Automation

## Purpose

The jansible-foundation automation provides consistent baseline configuration for all new containers and VMs. It's the only automation we maintain because it solves a real problem: every new container needs the same basic setup.

## What It Does

### User Management
- Creates `jan` user with sudo access
- Deploys SSH keys (public and private)
- Configures zsh shell with oh-my-zsh
- Removes unwanted default accounts

### Security Hardening
- SSH key-only authentication
- Fail2ban intrusion prevention
- UFW firewall (deny by default)
- Automated security updates

### Development Environment
- Essential packages (git, curl, nvim, etc.)
- Python development tools
- Network administration utilities
- Modern command-line tools (eza, neovim)

### Personal Environment
- Automated dotfiles deployment
- GitLab OAuth integration
- Scheduled dotfiles updates

### Monitoring
- Prometheus Node Exporter
- Basic health checks
- Log management and rotation

## How to Use

### For New Containers

**Initial Setup (Run once on new container):**

1. **Install prerequisites:**
   ```bash
   # Update package list
   apt update
   
   # Install git and ansible
   apt install -y git ansible
   ```

2. **Download and setup provision script:**
   ```bash
   # Download provision script from repository
   curl -o /usr/local/bin/provision-foundation https://gitlab.com/opajan/jansible-foundation/-/raw/main/scripts/provision.sh
   
   # Make script executable
   chmod +x /usr/local/bin/provision-foundation
   ```

3. **Run initial foundation setup:**
   ```bash
   # Execute foundation automation for first time
   /usr/local/bin/provision-foundation
   ```

4. **Verify setup:**
   ```bash
   # Check if jan user was created
   id jan
   
   # Verify cron job was installed
   crontab -l
   ```

After initial setup:
- Foundation automation runs automatically every 30 minutes
- Container is ready with full baseline configuration

### Manual Application
```bash
ansible-pull -U https://gitlab.com/opajan/jansible-foundation.git playbooks/foundation.yml
```

## Automation Schedule

### Cron Jobs
```bash
# Foundation automation (every 30 minutes)
*/30 * * * * /usr/local/bin/provision-foundation > /dev/null 2>&1

# Dotfiles updates (per user, every 30 minutes)
*/30 * * * * cd /home/jan/.dotfiles && bash ./update.sh > /dev/null 2>&1
```

### What Gets Updated
- Security patches (automatic)
- User configurations (if changed in repo)
- Development tools (if versions change)
- Monitoring configuration (if modified)

## Repository

- **URL**: https://gitlab.com/opajan/jansible-foundation.git
- **Logs**: `/var/log/jansible-foundation.log`
- **Cache**: `/var/cache/jansible/foundation.yml`

## Troubleshooting

### Check Automation Status
```bash
# View recent logs
tail -f /var/log/jansible-foundation.log

# Check last deployment
cat /var/cache/jansible/foundation.yml

# Manual execution (verbose)
ansible-pull -v -U https://gitlab.com/opajan/jansible-foundation.git playbooks/foundation.yml
```

### Common Issues
- **SSH key deployment**: Check vault encryption is working
- **Package installation**: Verify network connectivity
- **Dotfiles failure**: Check GitLab OAuth token validity

## Why We Keep This

Unlike service-specific automation, foundation automation:
- Runs on ALL containers (universal value)
- Saves significant setup time for each new container
- Provides security consistency across infrastructure
- Handles cross-cutting concerns (users, SSH, security)

We eliminated service-specific automation because services are deployed once and run for years. Foundation setup happens for every new container.
