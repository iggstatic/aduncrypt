#!/bin/sh
set -e

# Bootstrap or refresh the root trust anchor for DNSSEC validation. Unbound
# tracks key rollovers (RFC 5011) only while it is running, so also run this
# on every start in case the container was stopped across a rollover.
# unbound-anchor exits 1 when it had to update the key, which is not an error.
echo "Checking the root trust anchor for DNSSEC validation..."
unbound-anchor -a /var/lib/unbound/root.key || [ $? -eq 1 ]

# Every service runs as its own unprivileged user. AdGuard Home keeps
# CAP_NET_BIND_SERVICE as an ambient capability so it can bind ports 53 and
# 80, plus CAP_NET_RAW for its DHCP server if the container was granted it.
AGH_CAPS="+net_bind_service"
if setpriv --inh-caps +net_raw true 2>/dev/null; then
  AGH_CAPS="$AGH_CAPS,+net_raw"
fi

chown -R unbound:unbound /var/lib/unbound
chown -R dnscrypt:dnscrypt /var/cache/dnscrypt-proxy

echo "Setting correct permissions for AdGuard Home directories..."
chown -R adguard:adguard /opt/adguardhome/work /opt/adguardhome/conf
chmod 700 /opt/adguardhome/work
chmod 700 /opt/adguardhome/conf

echo "Checking Unbound configuration..."
su-exec unbound unbound-checkconf /opt/unbound/unbound.conf

# Forward stop signals to all services so the container shuts down cleanly
STOPPING=""
trap 'STOPPING=1; kill -TERM $DNSCRYPT_PID $UNBOUND_PID $AGH_PID 2>/dev/null' TERM INT

echo "Starting DNSCrypt-Proxy..."
su-exec dnscrypt dnscrypt-proxy -config /opt/dnscrypt/dnscrypt-proxy.toml &
DNSCRYPT_PID=$!

echo "Starting Unbound DNS resolver..."
su-exec unbound unbound -d -c /opt/unbound/unbound.conf &
UNBOUND_PID=$!

echo "Starting AdGuard Home (capabilities: $AGH_CAPS)..."
setpriv --reuid adguard --regid adguard --init-groups \
  --inh-caps "$AGH_CAPS" --ambient-caps "$AGH_CAPS" \
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
