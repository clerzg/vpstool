#!/bin/sh

apk add uuidgen

case "$(uname -m)" in
    x86_64 | x64 | amd64 ) ARCH_SB="sing-box-alpine-amd64" ;;
    arm64 | aarch64 ) ARCH_SB="sing-box-alpine-arm64" ;;
    * ) echo "错误：不支持的架构"; exit 1 ;;
esac

mkdir -p /usr/local/bin
wget -O /usr/local/bin/sing-box https://github.com/clerzg/sing-box-mini/releases/latest/download/${ARCH_SB}
chmod +x /usr/local/bin/sing-box

# 4. 生成配置参数
UUID=$(uuidgen)
PORT=$(shuf -i 10000-65000 -n 1)
IP=$(wget -qO- api.ipify.org)

# 5. 写入配置文件
mkdir -p /etc/sing-box
cat <<EOF > /etc/sing-box/config.json
{
  "log": {
    "disabled": true
  },
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

# 6. 配置最轻量的 local.d 开机自启，并注入 64M 内存优化参数
# 放弃 rc-service，因为 OpenRC 太重，且无法在没有宿主机权限时稳定控温
mkdir -p /etc/local.d
cat <<'EOF' > /etc/local.d/sing-box.start
#!/bin/sh
# 限制 Go 的 GC 频率和最大内存，卡死在 45MB 以内，防止运行中 OOM
export GOGC=20
export GOMEMLIMIT=45MiB
/usr/local/bin/sing-box run -c /etc/sing-box/config.json >/dev/null 2>&1 &
EOF

chmod +x /etc/local.d/sing-box.start
rc-update add local default 2>/dev/null

# 7. 现场直接启动（带上内存限制）
export GOGC=20
export GOMEMLIMIT=45MiB
/usr/local/bin/sing-box run -c /etc/sing-box/config.json >/dev/null 2>&1 &

# 8. 输出连接
echo "vless://$UUID@$IP:$PORT?type=ws#Alpine_SB"