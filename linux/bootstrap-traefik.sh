#!/bin/bash

# https://devpress.csdn.net/cloudnative/62f2dd72c6770329307f7265.html
wget https://github.com/traefik/traefik/releases/download/v3.0.0-beta4/traefik_v3.0.0-beta4_linux_amd64.tar.gz
tar zxvf ./traefik_v3.0.0-beta4_linux_amd64.tar.gz

cp ./traefik /usr/local/bin
chown root:root /usr/local/bin/traefik
chmod 755 /usr/local/bin/traefik

# give the traefik binary the ability to bind to privileged ports (80, 443) as non-root
setcap 'cap_net_bind_service=+ep' /usr/local/bin/traefik

useradd --shell /usr/sbin/nologin -r traefik

mkdir -p /etc/traefik
touch /etc/traefik/traefik.yaml
mkdir -p /etc/traefik/acme
mkdir -p /etc/traefik/dynamic
chown -R root:root /etc/traefik
chown -R traefik:traefik /etc/traefik/*

touch /var/log/traefik.log
chown traefik:traefik /var/log/traefik.log

cat <<EOF > /etc/systemd/system/traefik.service
[Unit]
Description=traefik proxy
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
Restart=on-abnormal
; User and group the process will run as.
User=traefik
Group=traefik
; Always set "-root" to something safe in case it gets forgotten in the traefikfile.
ExecStart=/usr/local/bin/traefik --configfile=/etc/traefik/traefik.yaml
; Limit the number of file descriptors; see `man systemd.exec` for more limit settings.
LimitNOFILE=1048576
; Use private /tmp and /var/tmp, which are discarded after traefik stops.
PrivateTmp=true
; Use a minimal /dev (May bring additional security if switched to 'true', but it may not work on Raspberry Pi's or other devices, so it has been disabled in this dist.)
PrivateDevices=false
; Hide /home, /root, and /run/user. Nobody will steal your SSH-keys.
ProtectHome=true
; Make /usr, /boot, /etc and possibly some more folders read-only.
ProtectSystem=full
; … except /etc/ssl/traefik, because we want Letsencrypt-certificates there.
;   This merely retains r/w access rights, it does not add any new. Must still be writable on the host!
ReadWriteDirectories=/etc/traefik/acme
; The following additional security directives only work with systemd v229 or later.
; They further restrict privileges that can be gained by traefik. Uncomment if you like.
; Note that you may have to add capabilities required by any plugins in use.
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

chown root:root /etc/systemd/system/traefik.service
chmod 644 /etc/systemd/system/traefik.service
systemctl daemon-reload
systemctl start traefik.service
