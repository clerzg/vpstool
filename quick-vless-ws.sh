#!/bin/sh

# 1. 强制释放系统可能存在的缓存，腾出每一 K 内存
sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null

# 2. 强制单线程，用 apk 只安装极轻量的基础工具（这几个包极小，apk 绝不会 OOM）
export FORCE_SINGLE_THREAD=1
apk add --no-cache curl uuidgen

mkdir -p /usr/local/bin
wget -O /usr/local/bin/sing-box https://github.com/clerzg/sing-box-mini/releases/latest/download/sing-box-alpine-${uname -m}
chmod +x /usr/local/bin/sing-box

# 4. 生成配置参数
UUID=$(uuidgen)
PORT=$(shuf -i 10000-65000 -n 1)
IP=$(curl -s ifconfig.me)

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
echo "vless://$UUID@$IP:$PORT?type=ws#Alpine_Official_SB"