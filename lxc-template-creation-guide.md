# Ubuntu 24.04 LXC Template Creation

## Template Creation Commands

```bash
# Create base LXC container
pct create 901 /templates/template/cache/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
  --hostname ubuntu2404-template \
  --cores 1 \
  --memory 1024 \
  --rootfs cts:4 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --ostype ubuntu \
  --template 1 \
  --feature nesting=1,fuse=1 \
  --unprivileged 0 \
  --onboot 1

# Convert to working container
pct set 901 -template 0
pct start 901

# Configure locale (critical for Ansible)
pct exec 901 -- locale-gen en_US.UTF-8
pct exec 901 -- /bin/bash -c 'echo "LANG=en_US.UTF-8" > /etc/default/locale'
pct exec 901 -- /bin/bash -c 'echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale'
pct stop 901 && pct start 901

# Install prerequisites
pct exec 901 -- apt update
pct exec 901 -- apt install -y git ansible curl

# Test SSL functionality (critical verification)
pct exec 901 -- ansible localhost -m get_url -a "url=https://dystroy.org/dysk/download/x86_64-linux/dysk dest=/tmp/ssl_test mode=0755" -c local

# Download and install provision script
pct exec 901 -- curl -o /usr/local/bin/provision-foundation https://gitlab.com/opajan/jansible-foundation/-/raw/main/scripts/provision.sh
pct exec 901 -- chmod +x /usr/local/bin/provision-foundation

# Copy vault file and run foundation automation
pct push 901 /etc/.vault.txt /etc/.vault.txt
pct exec 901 -- ansible-pull -U https://gitlab.com/opajan/jansible-foundation.git playbooks/foundation.yml

# Clean up and convert to template
pct exec 901 -- rm /etc/.vault.txt
pct exec 901 -- history -c
pct exec 901 -- poweroff
pct set 901 -template 1
```

## Requirements

- Ubuntu 24.04 template file in `/templates/template/cache/`
- Template hostname added to foundation automation inventory
- Vault file available at `/etc/.vault.txt`
- Container must be **privileged** (no --unprivileged flag) for network compatibility

## Template Usage

Template is ready for cloning with `pct clone 901 <new_id> --hostname <name> --full`
