# Infrastructure Architecture Principles

## Core Philosophy: The Homelab Dichotomy

A homelab serves two distinct purposes that require different approaches:

### Production Zone
Critical "always-on" services (Pi-hole, databases, Home Assistant). Requires:
- **Stability and reliability first**
- **Operational simplicity over complexity**
- **Rigorous change management**
- **Proven, battle-tested approaches**

### Playground Zone  
Experimentation and learning environment. Allows:
- **Controlled complexity for education**
- **Rapid iteration and testing**
- **Acceptable downtime for learning**
- **Cutting-edge technology exploration**

## Primary Architecture Pattern: Service-per-LXC

### Design Principles

**Perfect Service Isolation**
- Each service runs in its own dedicated LXC container
- Dedicated resources and environment per service
- No container layer complexity or overhead
- Independent service lifecycle management

**Operational Clarity**
- Direct systemctl service management
- Native OS logs and troubleshooting tools
- Standard package managers (apt, snap) for installation
- No container runtime or image management

**Template-Based Consistency**
- Ubuntu 24.04 LTS base template (CT 901)
- Foundation automation pre-configured
- Proven SSL and networking configuration
- Predictable deployment experience

**Systematic Resource Allocation**
- Logical IP ranges based on service function (*see Infrastructure Catalog for complete IP allocation strategy*)
- Consistent storage patterns using `/lxcdata/<service>`
- Standardized CPU/RAM allocation by service type
- Organized backup and monitoring coverage

### Foundation Automation Scope

Applied automatically to ALL LXC containers:

**Baseline Security & Management**
- User management (jan user, SSH keys)
- SSH hardening and key-based authentication
- UFW firewall configuration
- fail2ban installation and configuration

**Essential Tooling**
- Development tools (nvim, git, htop, curl, wget)
- System monitoring and logging tools
- Network diagnostic utilities
- Package management optimization

**Foundation-Level ONLY**
- No service-specific configurations
- No service installations or business logic
- No service-specific networking or storage

*For foundation automation execution procedures, see LXC Deployment Guide.*

### Deployment Philosophy

**Documentation Over Automation**
- Manual deployment procedures for service-specific configuration
- Clear, step-by-step deployment guides
- One-time setup with multi-year operational life
- Emphasis on understanding over convenience

**Proven Manual Procedures**
- Template-based LXC creation from CT 901
- Standard package manager installation
- Native service configuration files
- Direct filesystem and network management

**External Service Integration**
- Cloudflare tunnel for all external access (no port forwarding)
- Proven external solutions over complex self-hosting
- SSL termination handled by Cloudflare
- Simplified access patterns and routing

## Network Architecture Principles

### Systematic IP Allocation Strategy

**Network Subnet**: 192.168.144.0/23
- **Static Services**: 192.168.144.0/24 (infrastructure and services)
- **DHCP Pool**: 192.168.145.0/24 (dynamic client assignments)

**Design Benefits**
- **Service Identification**: IP address immediately indicates service category
- **Troubleshooting**: Network issues easier to diagnose with logical grouping
- **Security Planning**: Firewall rules organized by IP ranges
- **Capacity Planning**: Clear visibility into range utilization
- **Scalability**: Each category accommodates growth
- **Management Simplification**: DNS/monitoring patterns follow IP patterns

*For complete IP range definitions and allocation strategy, see Infrastructure Catalog document.*

### DNS and Service Discovery

**Internal Resolution**
- Pi-hole as primary DNS server (192.168.144.20)
- .local domain for internal services
- Router DHCP configured to distribute Pi-hole
- Automatic hostname resolution for all services

*For DNS integration procedures and hostname management, see LXC Deployment Guide.*

**External Access**
- Cloudflare tunnel ONLY (no port forwarding)
- SSL termination handled by Cloudflare
- Centralized external routing configuration
- No reverse proxy or certificate management complexity

**SSH Security Architecture**
- Jump box pattern: All LXC SSH access restricted to Proxmox host only
- Container firewalls allow SSH from 192.168.144.10 exclusively
- External access via ProxyJump: `ssh -J server <container-hostname>`
- Eliminates direct network SSH exposure while maintaining operational simplicity

*For external URL mappings, see Infrastructure Catalog.*

## Storage Architecture

### Persistent Data Strategy

**Standardized Storage Patterns**
- `/lxcdata/<service-name>` on Proxmox host
- Mounted as `/data` within each LXC container
- Consistent backup coverage across all services
- Clear separation of persistent vs. ephemeral data

*For current storage allocations and service-specific storage details, see Infrastructure Catalog.*

**Storage Pool Allocation**
- **nvme_pool**: VM disks and high-performance storage
- **ssd_pool**: Container and VM data and databases
- **media_pool**: Large media files and archives  
- **backup_pool**: Backup storage and ISO images

### Backup Architecture

**Two-Layer Enterprise Backup Strategy**

**Layer 1: VM/Container Snapshots**
- Daily Proxmox vzdump at 3:00 AM
- Complete system state capture
- 2-day retention for quick rollbacks
- Full VM/container restoration capability

**Layer 2: Data-Level Incremental**
- Daily rsync of `/lxcdata/*` at 1:00 AM
- 7-day retention for granular recovery
- File-level restoration capability
- Incremental with compression

*For backup coverage details by service, see Infrastructure Catalog.*

## Service Deployment Patterns

### Standard Service-per-LXC Deployment

**Phase 1: LXC Creation**
1. Clone from Ubuntu 24.04 template (CT 901)
2. Assign static IP from appropriate service range (*reference Infrastructure Catalog*)
3. Configure CPU/RAM based on service requirements
4. Mount persistent storage: `/lxcdata/<service>` → `/data`

**Phase 2: Infrastructure Integration**
1. Foundation automation applies automatically
2. Add DNS entry to Pi-hole configuration  
3. Configure UFW firewall rules as needed
4. Test hostname resolution and connectivity

**Phase 3: Service Installation**
1. Manual package installation (apt, snap, etc.)
2. Service-specific configuration using `/data` paths
3. Configure service to start on boot (systemctl)
4. Test service functionality and external access

**Phase 4: Documentation & Monitoring**
1. Create comprehensive deployment guide
2. Update infrastructure catalog with service details
3. Configure service-specific monitoring if needed
4. Test backup coverage and restoration procedures

### Alternative Pattern: Appliance VMs

**When to Use Appliance Pattern**
- Complex, integrated software stacks (Home Assistant OS)
- Services requiring specific kernel modules or hardware access
- Pre-built appliances with integrated update systems
- Services where manual installation is impractical

**Appliance Deployment**
- Standard VM creation with appropriate resources
- IP assignment from appropriate service range (*reference Infrastructure Catalog*)
- DNS integration and external access configuration
- Use built-in appliance management systems

## Change Management Framework

### Production Zone Changes

**Critical Assessment Required**
1. **Operational Impact Analysis**: Does this change affect critical services?
2. **Complexity Evaluation**: Does this add unnecessary operational overhead?
3. **Alternative Assessment**: Can we achieve the goal with less complexity?
4. **Risk vs. Benefit**: Is the operational improvement worth the risk?

**Challenge Questions**
- What specific operational problem are you solving?
- How often do you actually encounter this issue?
- What happens if we don't make this change?
- Can an external service solve this more reliably?

**Approval Criteria**
- Change must provide genuine operational value
- Risk must be proportional to benefit
- Must align with service-per-LXC principles
- Must maintain or improve operational clarity

### Playground Zone Changes

**Learning-Focused Approach**
- Encourage experimentation and skill development
- Accept controlled complexity for educational value
- Provide guidance on best practices and pitfalls
- Enable safe learning without production impact

**Collaborative Assessment**
- What specific skills are you hoping to learn?
- What's a practical project you envision for this?
- Are you following a specific tutorial or concept?
- How does this fit into your learning goals?

## Operational Maintenance

### Service Management

**Service-per-LXC Services**
- Updates via standard package managers
- Direct configuration file management
- Native systemctl service control
- Standard OS troubleshooting procedures

**Legacy Container Services** (during migration)
- Update container images via established procedures
- Environment variable and volume configuration
- Podman container management
- Transitional approach until migration complete

**Appliance VM Services**
- Built-in appliance update systems
- Appliance-specific configuration methods
- Integrated management and monitoring tools

### Infrastructure Maintenance

**Automated Foundation**
- Foundation automation runs automatically
- Baseline security and tooling maintained
- Consistent environment across all LXCs
- No service-specific automation complexity

**Manual Service Configuration**
- Service-specific settings managed manually
- Clear deployment guides for reproducibility
- Configuration changes documented and tested
- Emphasis on understanding and maintainability

**Documentation Maintenance**
- Deployment guides updated when services change
- Infrastructure catalog updated after changes
- Migration status tracking for architecture evolution
- Version control for configuration and procedures

## Success Criteria

### Technical Excellence
- Services follow service-per-LXC patterns consistently
- IP allocation follows systematic ranges (*reference Infrastructure Catalog*)
- Storage patterns use standardized `/lxcdata` mounts
- External access via Cloudflare tunnel only

### Operational Clarity
- Troubleshooting uses standard OS tools
- Service management follows predictable patterns
- Documentation enables anyone to follow procedures
- Monitoring and backup coverage is comprehensive

### Long-term Sustainability  
- Architecture decisions prioritize maintainability
- Complexity is justified by genuine operational value
- External services used where they provide better reliability
- Skills and procedures are transferable and educational

---

**Architecture Status**: Service-per-LXC primary pattern with appliance VMs for specialized services  
**Foundation**: Ubuntu 24.04 LTS template with automated baseline configuration  
**External Access**: Cloudflare tunnel only, no port forwarding or reverse proxy complexity  
**Storage**: Systematic `/lxcdata` patterns with two-layer backup strategy
