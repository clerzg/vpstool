#!/bin/sh

echo "http://dl-cdn.alpinelinux.org/alpine/latest-stable/community" >> /etc/apk/repositories

export FORCE_SINGLE_THREAD=1

apk add --no-cache curl
apk add --no-cache sing-box

UUID=$(sing-box generate uuid)
PORT=$(shuf -i 10000-65000 -n 1)
IP=$(curl -s ifconfig.me)

mkdir -p /etc/sing-box
cat <<EOF > /etc/sing-box/config.json
{
  "log": {"disabled": true},
  "inbounds": [{
    "type": "vless",
    "listen": "::",
    "listen_port": $PORT,
    "users": [{"uuid": "$UUID"}],
    "transport": {"type": "ws"}
  }],
  "outbounds": [{"type": "direct"}]
}
EOF

rc-update add sing-box default
rc-service sing-box start

echo "vless://$UUID@$IP:$PORT?type=ws#Alpine_Official_SB"