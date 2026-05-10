#!/bin/sh

# 2. 安装必要依赖
apk add --no-cache curl jq uuidgen openssl

# 3. 确定架构
ARCH=$(uname -m)
case $ARCH in
    x86_64) BIN_ARCH="linux-amd64" ;;
    aarch64) BIN_ARCH="linux-arm64" ;;
    *) echo "不支持的架构: $ARCH"; exit 1 ;;
esac

# 4. 获取最新版并下载
echo "正在获取 sing-box 最新版本..."
TAG=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r .tag_name)
VERSION=${TAG#v}

curl -Lo /tmp/sing-box.tar.gz "https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-${BIN_ARCH}.tar.gz"
tar -zxvf /tmp/sing-box.tar.gz -C /tmp
mv /tmp/sing-box-${VERSION}-${BIN_ARCH}/sing-box /usr/local/bin/
chmod +x /usr/local/bin/sing-box
rm -rf /tmp/sing-box*

# 5. 生成配置参数 (注意：变量名已改为 WS_PATH)
UUID=$(uuidgen)
PORT=$(shuf -i 10000-65000 -n 1)
WS_PATH="/ws"
IP=$(curl -s ifconfig.me)

# 6. 创建配置文件
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
        "path": "$WS_PATH"
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

# 7. 创建 OpenRC 服务脚本
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

# 8. 设置自启并运行
rc-update add sing-box default
rc-service sing-box start

# 9. 输出结果
echo "------------------------------------------------"
echo "部署成功！"
echo "端口: $PORT"
echo "UUID: $UUID"
echo "路径: $WS_PATH"
echo "------------------------------------------------"
echo "VLESS 链接:"
echo "vless://$UUID@$IP:$PORT?type=ws&security=none&path=%2F${WS_PATH#/}#Alpine_SingBox"
echo "------------------------------------------------"