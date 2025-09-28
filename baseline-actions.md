# Baseline Actions for Any New Device / LXC

> Scope: Single host or LXC at first boot / initial handover.  
> Audience: Humans performing manual, template-based deployments.  
> Non-goals: Service-specific configs; automation that hides decisions.

## Prerequisites
- Proxmox/LXC template prepared (Ubuntu 24.04).
- Static IP & hostname chosen (align with IP schema).
- SSH access confirmed.

## Quick Checklist (tick as you go)
- [ ] Register host in inventory
- [ ] Add to DNS / Pi-hole
- [ ] Add to monitoring
- [ ] Add to infrastructure catalog
- [ ] Bootstrap secrets (`.vault.txt`)
- [ ] Install Ansible
- [ ] Bootstrap with `ansible-pull`
- [ ] Add provision job to root crontab
- [ ] Verify baseline health
- [ ] Document handover

## 1) Inventory Registration
**Goal:** Ensure host is managed and addressable by name.  
**Source of truth:** foundation repo inventory.  
**Action:** _[Path and snippet to be filled in during next step]_  
**Verify:** `ansible-inventory --list | jq '.hosts | contains(["<hostname>"])'`

## 2) DNS / Pi-hole
**Goal:** Hostname resolves locally; ad/DNS policy applies.  
**Action:** _[To be filled]_  
**Verify:** `dig +short <hostname>`

## 3) Monitoring
**Goal:** Node shows up in monitoring with basic metrics/alerts.  
**Action:** _[To be filled]_  
**Verify:** Dashboard/grafana panel shows CPU/RAM within 2–3 min.

## 4) Infrastructure Catalog
**Goal:** Device is discoverable with owner, purpose, lifecycle.  
**Action:** _[To be filled]_  
**Verify:** Catalog page lists the new host with tags.

## 5) Secrets Bootstrap (`.vault.txt`)
**Goal:** Minimal secrets file exists; permissions sane.  
**Action:** _[To be filled]_  
**Verify:** `ls -l ~/.vault.txt` shows `-rw-------`

## 6) Install Ansible (client)
**Goal:** Host can self-manage via pull model.  
**Action:** _[To be filled]_  
**Verify:** `ansible --version`

## 7) Bootstrap with `ansible-pull`
**Goal:** Idempotent converge to baseline.  
**Action:** _[To be filled]_  
**Verify:** Exit code 0; rerun yields “changed=0”.

## 8) Root Crontab Provision
**Goal:** Scheduled `ansible-pull` to maintain drift control.  
**Action:** _[To be filled]_  
**Verify:** `crontab -l` shows the job.

## 9) Baseline Health Checks
- `uptime`, `df -h`, `free -h`
- UFW/fail2ban status
- SSH hardened; key-only login

## 10) Decommissioning Hooks (Optional)
Checklist for clean teardown: DNS, monitoring, inventory, backups.

---

### Appendix A — Naming, IP Schema, and Tags
_[Reference your standard conventions here.]_

### Appendix B — Verification Commands (copy/paste block)
```bash
hostnamectl; ip -4 a; dig +short <hostname>; ufw status; fail2ban-client status

