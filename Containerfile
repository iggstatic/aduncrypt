FROM alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

ARG AGH_VER=v0.107.79
ARG TARGETARCH
ARG TARGETVARIANT

# Install packages, create directories, download files, and set permissions
RUN apk --no-cache add ca-certificates libcap tzdata unbound dnscrypt-proxy bind-tools \
    && mkdir -p /opt/adguardhome/conf /opt/adguardhome/work /var/lib/unbound /opt/unbound /opt/dnscrypt \
    && chown -R nobody:nogroup /opt/adguardhome \
    && wget -O /tmp/adguard.tar.gz https://github.com/AdguardTeam/AdGuardHome/releases/download/${AGH_VER}/AdGuardHome_linux_${TARGETARCH}${TARGETVARIANT}.tar.gz \
    && tar xf /tmp/adguard.tar.gz ./AdGuardHome/AdGuardHome --strip-components=2 -C /opt/adguardhome \
    && chown nobody:nogroup /opt/adguardhome/AdGuardHome \
    && setcap 'CAP_NET_BIND_SERVICE=+eip' /opt/adguardhome/AdGuardHome \
    && rm -rf /tmp/* /var/cache/apk/*

# Copy files
COPY unbound/unbound.conf /opt/unbound/unbound.conf
COPY dnscrypt/dnscrypt-proxy.toml /opt/dnscrypt/dnscrypt-proxy.toml
COPY scripts/ /opt/scripts/

WORKDIR /opt

VOLUME ["/opt/adguardhome/conf", "/opt/adguardhome/work", "/opt/unbound", "/opt/dnscrypt"]

EXPOSE 53/tcp 53/udp 67/udp 68/udp 80/tcp 443/tcp 443/udp 853/tcp 853/udp 3000/tcp 3000/udp 5443/tcp 5443/udp 6060/tcp

HEALTHCHECK --interval=30s --timeout=15s --start-period=30s --retries=3 \
    CMD sh /opt/scripts/healthcheck.sh || exit 1

CMD ["/opt/scripts/entrypoint.sh"]
