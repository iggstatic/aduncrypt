#!/bin/sh
set -e

if [ ! -f /var/lib/unbound/root.key ]; then
  echo "Bootstrapping the root trust anchor for DNSSEC validation..."
  unbound-anchor -a /var/lib/unbound/root.key || [ $? -eq 1 ]
fi

chown -R unbound:unbound /var/lib/unbound
chown -R dnscrypt:dnscrypt /var/cache/dnscrypt-proxy

echo "Checking Unbound configuration..."
unbound-checkconf /opt/unbound/unbound.conf

echo "Setting correct permissions for AdGuard Home directories..."
chmod 700 /opt/adguardhome/work
chmod 700 /opt/adguardhome/conf

# Forward stop signals to all services so the container shuts down cleanly
STOPPING=""
trap 'STOPPING=1; kill -TERM $DNSCRYPT_PID $UNBOUND_PID $AGH_PID 2>/dev/null' TERM INT

echo "Starting DNSCrypt-Proxy..."
dnscrypt-proxy -config /opt/dnscrypt/dnscrypt-proxy.toml &
DNSCRYPT_PID=$!

echo "Starting Unbound DNS resolver..."
unbound -d -c /opt/unbound/unbound.conf &
UNBOUND_PID=$!

echo "Starting AdGuard Home..."
/opt/adguardhome/AdGuardHome -c /opt/adguardhome/conf/AdGuardHome.yaml -w /opt/adguardhome/work --no-check-update &
AGH_PID=$!

# Keep running only while all three services are alive. If any of them dies
# the container exits so the restart policy brings the whole stack back,
# instead of running degraded on the fallback path.
while [ -z "$STOPPING" ] \
   && kill -0 "$DNSCRYPT_PID" 2>/dev/null \
   && kill -0 "$UNBOUND_PID" 2>/dev/null \
   && kill -0 "$AGH_PID" 2>/dev/null; do
  sleep 5 &
  wait $! || true
done

if [ -n "$STOPPING" ]; then
  wait
  exit 0
fi

echo "A service exited unexpectedly, shutting down..."
kill -TERM "$DNSCRYPT_PID" "$UNBOUND_PID" "$AGH_PID" 2>/dev/null || true
wait
exit 1
