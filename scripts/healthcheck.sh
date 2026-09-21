#!/bin/sh

FILE=/opt/adguardhome/conf/AdGuardHome.yaml

# Before the setup wizard has been completed only the wizard on port 3000 exists
if [ ! -f "$FILE" ]; then
  wget -q --spider --timeout=1 http://localhost:3000 && printf 'Waiting for config to be finished' || exit 1
  exit 0
fi

# Ports come from the AdGuard Home config: "address: 0.0.0.0:80" under "http:"
# and "port: 53" under "dns:"
WEB_ADDR=$(awk '/^http:/{s=1;next} /^[^ ]/{s=0} s && /^  address:/{print $2; exit}' "$FILE")
WEB_PORT=${WEB_ADDR##*:}
DNS_PORT=$(awk '/^dns:/{s=1;next} /^[^ ]/{s=0} s && /^  port:/{print $2; exit}' "$FILE")

wget -q --spider --timeout=1 "http://localhost:${WEB_PORT:-80}" || exit 1

# End-to-end resolution through AdGuard Home -> Unbound -> dnscrypt-proxy
# drill options must come before the name: musl getopt does not reorder arguments
drill -p "${DNS_PORT:-53}" cloudflare.com @127.0.0.1 A | grep -qE '^cloudflare\.com\.[[:space:]]+[0-9]+[[:space:]]+IN[[:space:]]+A[[:space:]]' || exit 1
