#!/bin/sh
set -e

if [ ! -f /var/lib/unbound/root.key ]; then
  echo "Bootstrapping the root trust anchor for DNSSEC validation..."
  # unbound-anchor exits 1 when it had to fetch or update the anchor, 0 when nothing changed
  unbound-anchor -a /var/lib/unbound/root.key || [ $? -eq 1 ]
fi
# Unbound updates the anchor itself (RFC 5011) and needs to write the directory
chown -R unbound:unbound /var/lib/unbound

echo "Checking Unbound configuration..."
unbound-checkconf /opt/unbound/unbound.conf

echo "Setting correct permissions for AdGuard Home directories..."
chmod 700 /opt/adguardhome/work
chmod 700 /opt/adguardhome/conf

# Forward stop signals to all services so the container shuts down cleanly
trap 'kill -TERM $DNSCRYPT_PID $UNBOUND_PID $AGH_PID 2>/dev/null' TERM INT

echo "Starting DNSCrypt-Proxy..."
dnscrypt-proxy -config /opt/dnscrypt/dnscrypt-proxy.toml &
DNSCRYPT_PID=$!

echo "Starting Unbound DNS resolver..."
unbound -d -c /opt/unbound/unbound.conf &
UNBOUND_PID=$!

echo "Starting AdGuard Home..."
/opt/adguardhome/AdGuardHome -c /opt/adguardhome/conf/AdGuardHome.yaml -w /opt/adguardhome/work --no-check-update &
AGH_PID=$!

wait $AGH_PID
