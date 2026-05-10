#!/bin/sh

# 1. 安装必要依赖
apk add --no-cache curl jq uuidgen

# 2. 获取最新版本并下载
ARCH=$(uname -m)
case $ARCH in
    x86_64) BIN_ARCH="linux-amd64" ;;
    aarch64) BIN_ARCH="linux-arm64" ;;
    *) echo "不支持的架构: $ARCH"; exit 1 ;;
esac

echo "正在获取最新版本..."
TAG=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r .tag_name)
VERSION=${TAG#v}

curl -Lo /tmp/sing-box.tar.gz "https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-${BIN_ARCH}.tar.gz"
tar -zxvf /tmp/sing-box.tar.gz -C /tmp
mv /tmp/sing-box-${VERSION}-${BIN_ARCH}/sing-box /usr/local/bin/
chmod +x /usr/local/bin/sing-box
rm -rf /tmp/sing-box*

# 3. 生成配置参数
UUID=$(uuidgen)
PORT=$(shuf -i 10000-65000 -n 1)
PATH="/ws"
IP=$(curl -s ifconfig.me)

# 4. 创建配置文件
mkdir -p /etc/sing-box
cat <<EOF > /etc/sing-box/config.json
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": $PORT,
      "users": [
        {
          "uuid": "$UUID"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "$PATH"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF

# 5. 编写 OpenRC 服务脚本
cat <<EOF > /etc/init.d/sing-box
#!/sbin/openrc-run

name="sing-box"
description="sing-box service"
command="/usr/local/bin/sing-box"
command_args="run -c /etc/sing-box/config.json"
pidfile="/run/\${RC_SVCNAME}.pid"
command_background=true

depend() {
    need net
    after firewall
}
EOF

chmod +x /etc/init.d/sing-box

# 6. 设置开机自启并启动
rc-update add sing-box default
rc-service sing-box start

# 7. 生成并输出链接
echo "------------------------------------------------"
echo "部署完成！"
echo "端口: $PORT"
echo "UUID: $UUID"
echo "路径: $PATH"
echo "------------------------------------------------"
echo "VLESS 链接 (不带 TLS):"
echo "vless://$UUID@$IP:$PORT?type=ws&security=none&path=%2Fws#Alpine-SingBox"
echo "------------------------------------------------"