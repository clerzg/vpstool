#!/bin/sh

# 1. 强制释放系统可能存在的缓存，腾出每一 K 内存
sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null

# 2. 强制单线程，用 apk 只安装极轻量的基础工具（这几个包极小，apk 绝不会 OOM）
export FORCE_SINGLE_THREAD=1
apk add --no-cache curl tar

# 3. 获取最新的官方轻量静态二进制 sing-box (以 amd64 为例，如果是 arm64 请自行修改链接)
# 静态包解压即用，不经过 apk 复杂的依赖计算，内存消耗微乎其微
DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v1.8.5/sing-box-1.8.5-linux-amd64.tar.gz"
curl -Lo /tmp/sing-box.tar.gz $DOWNLOAD_URL
tar -xzf /tmp/sing-box.tar.gz -C /tmp/
mv /tmp/sing-box-*/sing-box /usr/local/bin/
rm -rf /tmp/sing-box*

# 4. 生成配置参数
UUID=$(/usr/local/bin/sing-box generate uuid)
PORT=$(shuf -i 10000-65000 -n 1)
IP=$(curl -s ifconfig.me)

# 5. 写入配置文件
mkdir -p /etc/sing-box
cat <<EOF > /etc/sing-box/config.json
{
  "log": {
    "error": "/dev/null",
    "loglevel": "none"
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