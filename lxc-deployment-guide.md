# LXC Service Deployment Guide

## Standard LXC Creation Process

### 1. Clone and Configure
```bash
pct clone 901 <ID> --hostname <name> --full
pct set <ID> --cores <CPU> --memory <RAM> --rootfs cts:subvol-<ID>-disk-0,size=<SIZE>
pct set <ID> -net0 name=eth0,bridge=vmbr0,firewall=1,gw=192.168.144.1,ip=<IP>/23
pct set <ID> -mp0 /lxcdata/<service>,mp=/data
mkdir -p /lxcdata/<service>
pct set <ID> -onboot 1
pct start <ID>
```

*For IP assignment, reference the Infrastructure Catalog document for appropriate IP ranges based on service type (Database: 40-59, Application: 60-99, Media: 100-119, etc.)*

### 2. Infrastructure Integration

#### Step 1: Update Foundation Automation Inventory
- **Add hostname to Git repository**: Update jansible-foundation inventory/hosts file with new hostname
- **Commit and push changes**: Foundation automation will fail if hostname is not in inventory

#### Step 2: Foundation Automation

**CRITICAL PREREQUISITES:**
1. **Hostname must be added to jansible-foundation Git inventory BEFORE running automation**
2. **Foundation automation will fail if hostname is not in inventory**
3. **Vault file must be available on Proxmox host at `/etc/.vault.txt`**

**Execution:**
```bash
# Copy vault file to container
pct push <ID> /etc/.vault.txt /etc/.vault.txt

# Run foundation automation (only after hostname is in Git inventory)
pct exec <ID> -- ansible-pull -U https://gitlab.com/opajan/jansible-foundation.git playbooks/foundation.yml

# MANUAL: Add automated cron job (foundation automation doesn't configure this automatically)
pct exec <ID> -- bash -c 'echo "*/30 * * * * /usr/local/bin/provision-foundation > /dev/null 2>&1" | crontab -'
```

**Foundation Automation Provides:**
- User management (jan user, SSH keys, shell configuration)
- Security hardening (UFW, fail2ban, SSH configuration)
- Essential tools (nvim, git, development utilities)
- System monitoring (Node Exporter on port 9100)

*For foundation automation scope and philosophy, see Architecture Principles.*

#### Step 3: Configure Container Firewall

**Enable UFW and Apply Standard Rules:**
```bash
# Enable UFW (use --force to skip interactive prompt)
pct exec <ID> -- ufw --force enable

# Apply foundation firewall rules (required for ALL containers)
pct exec <ID> -- bash -c "
ufw allow from 192.168.144.10 to any port 22 comment 'SSH from Proxmox host only'
ufw allow 9100/tcp comment 'Node Exporter monitoring'
"
```

**Add Service-Specific Rules:**
```bash
# For web applications (public access)
pct exec <ID> -- ufw allow <PORT>/tcp comment '<SERVICE> web interface'

# For database servers (restricted access)
pct exec <ID> -- ufw allow from <CLIENT_IP> to any port <DB_PORT> comment '<SERVICE> from <CLIENT_NAME>'
```

**Verify Firewall Configuration:**
```bash
# Confirm UFW is active with proper rules
pct exec <ID> -- ufw status verbose
```

#### Step 4: DNS Integration

**Add hostname to Pi-hole for internal resolution:**

```bash
# SSH to Pi-hole server
ssh jan@192.168.144.20

# Edit Pi-hole TOML configuration
sudo /usr/local/bin/nvim /opt/pihole/etc-pihole/pihole.toml
```

Add hostname entry to hosts array under `[dns]`:
```toml
"<IP> <hostname>.local <hostname>"
```

```bash
# Restart Pi-hole to apply changes
sudo podman restart pihole

# Test resolution from any network device
nslookup <hostname>.local
```

*For complete hostname listings and Pi-hole configuration, see Infrastructure Catalog.*

#### Step 5: Monitoring Integration
- **Update monitor-services Git repository**
- **Add to check-services.sh**: Service endpoint for health monitoring
- **Add to collect-metrics.sh**: Hostname for system metrics collection
- **Commit changes**: Automation will deploy within 30 minutes

### 3. Service Installation
See service-specific sections below.

---

## Service Configurations

*For service specifications (IP addresses, resources, dependencies), reference the Infrastructure Catalog. This section focuses on installation and configuration procedures.*

### PostgreSQL Database (CT 100)
- **Service Type**: Database server for application backends
- **Installation**:
  ```bash
  apt install postgresql postgresql-contrib
  ```
- **Configuration**:
  ```bash
  # Configure data directory
  mkdir -p /data/postgresql && chown postgres:postgres /data/postgresql
  sudo -u postgres /usr/lib/postgresql/16/bin/initdb -D /data/postgresql
  
  # Update PostgreSQL configuration
  sed -i "s|#data_directory = 'ConfigDir'|data_directory = '/data/postgresql'|" /etc/postgresql/16/main/postgresql.conf
  sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /data/postgresql/postgresql.conf
  
  # Configure client authentication  
  echo "host all all 192.168.144.0/23 trust" >> /data/postgresql/pg_hba.conf
  
  # Restart service
  systemctl restart postgresql
  ```
- **Firewall Configuration**:
  ```bash
  ufw allow 22/tcp comment 'SSH access'
  ufw allow 9100/tcp comment 'Node Exporter monitoring'
  ufw allow from 192.168.144.60 to any port 5432 comment 'PostgreSQL from Planka LXC'
  ufw allow from 192.168.144.25 to any port 5432 comment 'PostgreSQL from monitor'
  ```
- **Database Management**: `sudo -u postgres createdb <dbname>`

### MariaDB Database (CT 101)
- **Service Type**: Database server for WordPress sites
- **Installation**:
  ```bash
  apt install mariadb-server mariadb-client
  ```
- **Configuration**:
  ```bash
  # Secure installation (set root password, see Bitwarden vault)
  mysql_secure_installation
  
  # Configure network access
  sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
  systemctl restart mariadb
  ```
- **Firewall Configuration**:
  ```bash
  ufw allow 22/tcp comment 'SSH access'
  ufw allow 9100/tcp comment 'Node Exporter monitoring'
  ufw allow from 192.168.144.25 to any port 3306 comment 'MariaDB from monitor server'
  ufw allow from 192.168.144.70 to any port 3306 comment 'MariaDB from WordPress main'
  ufw allow from 192.168.144.71 to any port 3306 comment 'MariaDB from WordPress kledingruil'
  ```
- **User Management**: 
  ```sql
  CREATE USER 'username'@'%' IDENTIFIED BY 'password';
  GRANT ALL PRIVILEGES ON database_name.* TO 'username'@'%';
  FLUSH PRIVILEGES;
  ```

### Plex Media Server (CT 102)
- **Service Type**: Media streaming server
- **Additional Storage**: Configure media mount before installation
  ```bash
  pct set 102 -mp1 /media,mp=/media
  ```
- **Installation**:
  ```bash
  # Add Plex repository
  curl https://downloads.plex.tv/plex-keys/PlexSign.key | apt-key add -
  echo "deb https://downloads.plex.tv/repo/deb public main" | tee /etc/apt/sources.list.d/plexmediaserver.list
  
  # Install Plex
  apt update && apt install plexmediaserver
  ```
- **Firewall Configuration**:
  ```bash
  ufw allow 22/tcp comment 'SSH access'
  ufw allow 9100/tcp comment 'Node Exporter monitoring'
  ufw allow 32400/tcp comment 'Plex web interface'
  ufw allow 1900/udp comment 'DLNA discovery'
  ufw allow 32469/tcp comment 'Plex companion'
  ```
- **Initial Setup**: Access http://[container-ip]:32400/web for configuration

### Planka Project Management (CT 103)
- **Service Type**: Kanban project management
- **Node.js Installation**:
  ```bash
  # Add NodeSource repository for Node.js 22
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
  
  apt update && apt install nodejs unzip build-essential
  ```
- **Planka Installation**:
  ```bash
  # Download and install Planka
  cd /data
  curl -fsSL -O https://github.com/plankanban/planka/releases/latest/download/planka-prebuild.zip
  unzip planka-prebuild.zip && rm planka-prebuild.zip
  cd planka && npm install
  
  # Configure environment
  cp .env.sample .env
  # Edit .env with:
  # BASE_URL=https://tasks.janvv.nl
  # DATABASE_URL=postgresql://postgres@192.168.144.40:5432/planka
  ```
- **Firewall Configuration**:
  ```bash
  ufw allow 22/tcp comment 'SSH access'
  ufw allow 9100/tcp comment 'Node Exporter monitoring'
  ufw allow 1337/tcp comment 'Planka web interface'
  ```
- **Systemd Service**: Create systemd service for automatic startup

### WordPress Sites (CT 104 & CT 105)
- **Service Type**: WordPress websites (JokeGoudriaan & Kledingruil)
- **LAMP Stack Installation**:
  ```bash
  # Install Apache, PHP, and modules
  apt update
  apt install -y apache2 php php-mysql php-curl php-gd php-mbstring php-xml php-zip php-intl php-soap unzip wget
  
  # Enable Apache modules
  a2enmod rewrite ssl
  
  # Create WordPress directory
  mkdir -p /data/wordpress && chown -R www-data:www-data /data/wordpress
  ```
- **Apache Configuration**: Create site configuration in `/etc/apache2/sites-available/`
  ```apache
  <VirtualHost *:80>
      ServerName [hostname].local
      ServerAlias localhost
      DocumentRoot /data/wordpress
      
      <Directory /data/wordpress>
          AllowOverride All
          Require all granted
      </Directory>
      
      ErrorLog ${APACHE_LOG_DIR}/wordpress_error.log
      CustomLog ${APACHE_LOG_DIR}/wordpress_access.log combined
  </VirtualHost>
  ```
- **Firewall Configuration**:
  ```bash
  ufw allow 22/tcp comment 'SSH access'
  ufw allow 9100/tcp comment 'Node Exporter monitoring'
  ufw allow 80/tcp comment 'WordPress web interface'
  ```
- **Site Management**:
  ```bash
  a2dissite 000-default.conf
  a2ensite [site-config].conf
  systemctl reload apache2
  ```
- **WordPress Configuration**: Configure wp-config.php with MariaDB connection details
- **File Permissions**: `chown -R www-data:www-data /data/wordpress`

### n8n Workflow Automation (CT 106)
- **Service Type**: Workflow automation platform
- **Node.js Installation**:
  ```bash
  # Add NodeSource repository for Node.js 22
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
  
  apt update && apt install -y nodejs
  
  # Install n8n globally
  npm install -g n8n
  ```
- **Firewall Configuration**:
  ```bash
  ufw allow 22/tcp comment 'SSH access'
  ufw allow 9100/tcp comment 'Node Exporter monitoring'
  ufw allow 5678/tcp comment 'n8n web interface'
  ```
- **Systemd Service Configuration**: Create `/etc/systemd/system/n8n.service`
  ```ini
  [Unit]
  Description=n8n workflow automation
  After=network.target
  
  [Service]
  Type=simple
  User=jan
  Group=jan
  WorkingDirectory=/data/n8n
  Environment=N8N_USER_FOLDER=/data/n8n
  Environment=N8N_PORT=5678
  Environment=GENERIC_TIMEZONE=Europe/Amsterdam
  Environment=WEBHOOK_URL=https://n8n.janvv.nl
  Environment=N8N_EDITOR_BASE_URL=https://n8n.janvv.nl
  ExecStart=/usr/bin/n8n start
  Restart=always
  RestartSec=10
  
  [Install]
  WantedBy=multi-user.target
  ```
- **Service Management**:
  ```bash
  systemctl daemon-reload
  systemctl enable n8n
  systemctl start n8n
  ```

### Cloudflare Tunnel (CT 107)
- **Service Type**: External access tunnel for all services
- **Installation**:
  ```bash
  # Download and install cloudflared
  curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
  apt install -y /tmp/cloudflared.deb

- **Create systemd service with tunnel token**
```
  cat > /etc/systemd/system/cloudflared.service << 'EOF'
  [Unit]
  Description=cloudflared
  After=network-online.target
  Wants=network-online.target
  [Service]
  TimeoutStartSec=0
  Type=notify
  ExecStart=/usr/bin/cloudflared --no-autoupdate tunnel run --token [TUNNEL_TOKEN]
  Restart=on-failure
  RestartSec=5s
  [Install]
  WantedBy=multi-user.target
  EOF

  # Enable and start service
  systemctl daemon-reload
  systemctl enable cloudflared
  systemctl start cloudflared  
```

- **Firewall Configuration**
```
  ufw allow 22/tcp comment 'SSH access'
  ufw allow 9100/tcp comment 'Node Exporter monitoring'
  # No additional inbound ports needed - outbound connections only
```
### lanproxy (CT 109)
- **Service Type**: Central LAN reverse proxy (Caddy)  
- **Purpose**: Terminates HTTPS for internal services using **split-horizon DNS** and a single entrypoint.  
  External access remains unchanged via Cloudflare Tunnel.

- **Container Configuration**:
  - **ID**: 109
  - **Hostname**: lanproxy
  - **IP Address**: 192.168.144.31/23 (Network Services range)
  - **Resources**: 1 core, 512 MB RAM, 16 GB disk
  - **Storage**: `/lxcdata/lanproxy → /data`
  - **Features**: nesting=1, fuse=1
  - **Onboot**: enabled

- **Foundation Setup**:
  Provisioned with standard automation (user, SSH, UFW, fail2ban, neovim, monitoring exporter).

- **Install Caddy with Cloudflare DNS plugin**:
  ```bash
  # Install Go and xcaddy (if not present)
  sudo apt install -y golang

  # Build custom Caddy with Cloudflare DNS provider
  /home/jan/go/bin/xcaddy build \
    --with github.com/caddy-dns/cloudflare

  # Replace system caddy binary
  sudo systemctl stop caddy
  sudo install -m 0755 ./caddy /usr/bin/caddy
  sudo systemctl start caddy
  ```

- **Cloudflare API Token**: 
  Token is stored in `/etc/caddy/caddy.env` and injected via systemd drop-in.  
  It must have **DNS:Edit** permissions for **every zone** that hosts services routed through lanproxy.  
  Example: both `janvv.nl` and `jokegoudriaan.nl` need to be included if services exist in both domains.

```bash
  CLOUDFLARE_API_TOKEN=<token>
  ```
  Permissions:
  ```bash
  sudo chmod 0640 /etc/caddy/caddy.env
  sudo chown root:caddy /etc/caddy/caddy.env
  ```

- **Systemd Environment Override**:
  ```ini
  # /etc/systemd/system/caddy.service.d/10-env.conf
  [Service]
  EnvironmentFile=/etc/caddy/caddy.env
  ```

  Apply:
  ```bash
  sudo systemctl daemon-reload
  sudo systemctl restart caddy
  ```

- **Caddyfile**: `/etc/caddy/Caddyfile`
  ```caddy
  {
    # Global options
  }

  # Health check
  :80 {
    respond "lanproxy up" 200
  }

  # For each service (except Proxmox):
  <service>.janvv.nl {
    tls {
      dns cloudflare {env.CLOUDFLARE_API_TOKEN}
    }
    encode zstd gzip
    reverse_proxy <IP>:<PORT>
  }

  # Proxmox
  proxmox.janvv.nl {
    tls {
      dns cloudflare {env.CLOUDFLARE_API_TOKEN}
    }
    encode zstd gzip
    reverse_proxy https://192.168.144.10:8006 {
      transport http {
        tls_insecure_skip_verify
      }
    }
  }
  ```

- **Apply Caddyfile changes**:
  ```bash
  sudo caddy fmt --overwrite /etc/caddy/Caddyfile
  sudo caddy validate --config /etc/caddy/Caddyfile
  sudo systemctl reload caddy
  ```

- **Pi-hole Integration** (`/opt/pihole/etc-pihole/pihole.toml`):
  For each service add a line in the hosts and dnsmasq_lines section
  ```toml
  [dns]
  hosts = [
    "192.168.144.31 <service>.janvv.nl",
  ]

  dnsmasq_lines = [
    "dhcp-option=15,local",
    "local=/<service>.janvv.nl/",
  ]
  ```

- **Firewall Configuration**:
  ```bash
  sudo ufw allow from 192.168.144.0/23 to any port 80  proto tcp comment 'LAN HTTP'
  sudo ufw allow from 192.168.144.0/23 to any port 443 proto tcp comment 'LAN HTTPS'
  sudo ufw allow 9100/tcp comment 'Node Exporter monitoring'
  ```

- **Verification**:
  ```bash
  nslookup <service>.janvv.nl 192.168.144.20
  curl -I https://<service>.janvv.nl
  openssl s_client -connect <service>.janvv.nl:443 -servername <service>.janvv.nl
  ```

### Web Server (CT 110)

- **Install Nginx + PHP-FPM + deps:
  ```bash
  pct exec 110 -- bash -lc '
  apt update
  apt install -y nginx php-fpm php-cli php-zip php-xml php-mbstring php-curl php-intl unzip
  systemctl enable --now nginx php8.3-fpm
  '
  ```

- ** Deploy Grav
  ```bash
  pct exec 110 -- bash -lc '
  set -e
  mkdir -p /data/www && cd /data
  curl -fsSLO https://getgrav.org/download/core/grav-admin/latest
  unzip -q latest -d /data
  mv /data/grav-admin /data/www || mv /data/grav /data/www
  chown -R www-data:www-data /data/www
  find /data/www -type d -exec chmod 755 {} \;
  find /data/www -type f -exec chmod 644 {} \;
  '
  ```

- **Nginx Site Config
  ```bash
  pct exec 110 -- bash -lc "
  cat >/etc/nginx/sites-available/grav <<'NGX'
  server {
      listen 80 default_server;
      server_name _;
      root /data/www;
      index index.php index.html;
  
      location / {
          try_files \$uri \$uri/ /index.php?\$query_string;
      }
  
      location ~ \.php$ {
          include snippets/fastcgi-php.conf;
          fastcgi_pass unix:/run/php/php8.2-fpm.sock;
      }
  
      # Hardened paths
      location ~* /(\.git|cache|bin|logs|backups|tests)/.*$ { return 403; }
      location ~* /(system|vendor)/.*\.(txt|md|yaml|php)$ { return 403; }
      location ~ /\. { deny all; }
  }
  NGX
  ln -sf /etc/nginx/sites-available/grav /etc/nginx/sites-enabled/grav
  rm -f /etc/nginx/sites-enabled/default
  nginx -t && systemctl reload nginx
  "
  ```

---

## Firewall Management

### Firewall Rule Categories

**Public Services** (Allow from Anywhere):
- Web applications (HTTP/HTTPS ports)
- Media streaming services
- API endpoints accessed via Cloudflare tunnel

**Restricted Services** (Allow from Specific IPs):
- Database servers (PostgreSQL, MariaDB)
- Internal APIs
- Administrative interfaces

### Standard Comments Format
- `'SSH access'` - SSH management access
- `'Node Exporter monitoring'` - Prometheus monitoring
- `'<SERVICE> web interface'` - Web-accessible services
- `'<SERVICE> from <CLIENT>'` - Specific client access

### Firewall Verification

**Check UFW Status:**
```bash
# Check if UFW is enabled and view rules
pct exec <CONTAINER_ID> -- ufw status verbose
```

**Audit All Containers:**
```bash
# Check firewall status across all service containers
for vmid in {100..110}; do
  echo "=== Container $vmid ==="
  pct exec $vmid -- ufw status verbose
  echo
done
```

**Test Service Connectivity:**
```bash
# Test specific port connectivity
nc -zv <CONTAINER_IP> <PORT>

# Test from specific source (if restricted)
pct exec <SOURCE_CONTAINER> -- nc -zv <TARGET_IP> <PORT>
```

### Troubleshooting

**Service Not Accessible:**
1. Verify UFW is enabled: `pct exec <ID> -- ufw status`
2. Check if required port is allowed
3. Verify service is listening: `pct exec <ID> -- netstat -tlnp | grep <PORT>`
4. Test from expected client IP

**Database Connection Failed:**
1. Verify database client IP is allowed in firewall rules
2. Check database server is binding to correct interface
3. Test connectivity: `nc -zv <DB_IP> <DB_PORT>` from client container

**UFW Not Enabled:**
```bash
# Enable UFW and apply standard rules
pct exec <CONTAINER_ID> -- ufw --force enable
pct exec <CONTAINER_ID> -- bash -c "
ufw allow 22/tcp comment 'SSH access'
ufw allow 9100/tcp comment 'Node Exporter monitoring'
"
```

---
