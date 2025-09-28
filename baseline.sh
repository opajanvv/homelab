#!/usr/bin/env bash
set -euo pipefail

# Usage: ./baseline.sh <host>
# Example: ./baseline.sh baseline-test
# Prereqs:
#  - Host <host> is resolvable (add to Pi-hole first!)
#  - SSH key access to root@<host>
#  - Local /etc/.vault.txt exists on dev machine

HOST="$1"
VAULT="/etc/.vault.txt"
BOOTSTRAP="/tmp/baseline-bootstrap.sh"

if [[ ! -f "$VAULT" ]]; then
  echo "Local vault file $VAULT missing!" >&2
  exit 1
fi

# --- Write remote bootstrap to a temp file ---
cat >"$BOOTSTRAP" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (use sudo)." >&2
  exit 1
fi

if [[ ! -f /etc/.vault.txt ]]; then
  echo "Missing /etc/.vault.txt — expected from scp step." >&2
  exit 2
fi

apt-get update -y
apt-get install -y git ansible curl

curl -fsSL -o /usr/local/bin/provision-foundation \
  https://gitlab.com/opajan/jansible-foundation/-/raw/main/scripts/provision.sh
chmod +x /usr/local/bin/provision-foundation

ansible-pull -U https://gitlab.com/opajan/jansible-foundation.git playbooks/foundation.yml

( crontab -l 2>/dev/null | grep -v 'provision-foundation' ; \
  echo '*/30 * * * * /usr/local/bin/provision-foundation > /dev/null 2>&1' ) | crontab -

echo "== Verification =="
id jan || true
ufw status || true
curl -fsS http://localhost:9100/metrics | head -n 3 || echo "node_exporter metrics not yet available"

echo "Baseline bootstrap complete."
EOF

# --- Push files and execute remotely ---
scp "$VAULT" root@"$HOST":/etc/.vault.txt
scp "$BOOTSTRAP" root@"$HOST":/tmp/baseline-bootstrap.sh
ssh root@"$HOST" 'bash /root/baseline-bootstrap.sh'
