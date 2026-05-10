#!/bin/sh
# 1. 确保安装了 community 仓库（如果已开启会跳过）
echo "http://dl-cdn.alpinelinux.org/alpine/latest-stable/community" >> /etc/apk/repositories

# 2. 更新索引并直接安装
apk update
apk add --no-cache sing-box uuidgen curl

# 3. 生成配置 (UUID 和 随机端口)
UUID=$(uuidgen)
PORT=$(shuf -i 10000-65000 -n 1)
WS_PATH="/ws"
IP=$(curl -s ifconfig.me)

# 4. 写入官方包默认的路径 /etc/sing-box/config.json
mkdir -p /etc/sing-box
cat <<EOF > /etc/sing-box/config.json
{
  "log": { "level": "info" },
  "inbounds": [{
    "type": "vless",
    "tag": "vless-in",
    "listen": "::",
    "listen_port": $PORT,
    "users": [{"uuid": "$UUID"}],
    "transport": { "type": "ws", "path": "$WS_PATH" }
  }],
  "outbounds": [{"type": "direct", "tag": "direct"}]
}
EOF

# 5. 启动服务并设置开机自启
# 官方包自带了 OpenRC 脚本，直接用即可
rc-update add sing-box default
rc-service sing-box start

echo "vless://$UUID@$IP:$PORT?type=ws&security=none&path=%2F${WS_PATH#/}#Alpine_Official_SB"