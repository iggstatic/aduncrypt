#!/bin/sh

FILE=/opt/adguardhome/conf/AdGuardHome.yaml

if [ ! -f "$FILE" ]
then
   wget -q --spider --timeout=1 http://localhost:3000 && printf 'Waiting for config to be finished' || exit 1
elif PORT="$(grep '^bind_port:' "$FILE" | cut -f2 -d' ')" && ! wget -q --spider --timeout=1 "http://localhost:$PORT"
then
    exit 1
fi
