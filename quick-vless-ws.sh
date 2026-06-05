#!/bin/sh

# ====================================================
# 配置信息定义
# ====================================================
XRAY_BIN="/usr/local/bin/xray"
CONFIG_PATH="/etc/xray"
CONFIG_FILE="${CONFIG_PATH}/config.json"
INIT_FILE="/etc/init.d/xray"

echo "==== 1. 获取 Cloudflare trace 数据 ===="
INFO=$(wget -qO- --no-cache "https://www.cloudflare.com/cdn-cgi/trace")
IP=$(echo "${INFO}" | awk -F= '/^ip=/ {print $2}')
LOC=$(echo "${INFO}" | awk -F= '/^loc=/ {print $2}')

echo "当前服务器 IP: ${IP}"
echo "当前服务器位置: ${LOC}"
echo "==== 2. 动态生成随机端口 (10000-60000 之间) ===="
PORT=$(awk 'BEGIN{srand(); print int(rand()*(60000-10000+1))+10000}')
echo "分配的随机端口号为: ${PORT}"

echo "==== 3. 识别系统架构并下载/流式解压 Xray ==== "
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    XRAY_ARCH="64"
elif [ "$ARCH" = "aarch64" ]; then
    XRAY_ARCH="arm64-v8a"
else
    XRAY_ARCH="64"
fi

DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${XRAY_ARCH}.zip"

mkdir -p /usr/local/bin
echo "正在从官方获取最新的 Xray 压缩包..."

wget -O /tmp/xray.zip --no-cache "${DOWNLOAD_URL}"
if [ -f /tmp/xray.zip ]; then
    unzip -p /tmp/xray.zip xray > ${XRAY_BIN}
    rm -f /tmp/xray.zip
    chmod +x ${XRAY_BIN}
else
    echo "❌ 错误：下载 Xray 失败，请检查网络是否能通 GitHub！"
    exit 1
fi

echo "==== 4. 调用 Xray 核心动态生成 UUID ===="
UUID=$(${XRAY_BIN} uuid)
echo "生成的动态 UUID 为: ${UUID}"

echo "==== 5. 生成特制极简配置 ===="
mkdir -p ${CONFIG_PATH}
cat <<EOF > ${CONFIG_FILE}
{
  "log": {
    "loglevel": "none"
  },
  "inbounds": [
    {
      "port": ${PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {}
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

echo "==== 6. 自动注册 Alpine OpenRC 系统服务 ===="
cat <<EOF > ${INIT_FILE}
#!/sbin/openrc-run

description="Xray Mini Service for Alpine"
command="${XRAY_BIN}"
command_args="run -c ${CONFIG_FILE}"
pidfile="/run/\${RC_SVCNAME}.pid"
command_background="yes"

# 崩溃自动重启守护
respawn_delay=1
respawn_max=0

depend() {
    need net
}
EOF

chmod +x ${INIT_FILE}

echo "==== 7. 启动服务并设置开机自启 ===="
rc-update add xray default >/dev/null 2>&1
rc-service xray stop >/dev/null 2>&1
rc-service xray start

# 拼接专属 VLESS 节点链接
VLESS_LINK="vless://${UUID}@${IP}:${PORT}?type=ws&encryption=none#${LOC}"

echo "=========================================="
echo "🎉 部署完成！已经在 Alpine 后台静默运行。"
echo "=========================================="
echo "👇 你的专用 VLESS 节点链接（直接整行复制）："
echo ""
echo "${VLESS_LINK}"
echo ""
echo "=========================================="
echo "💡 实用运维指令："
echo "查看运行状态: rc-service xray status"
echo "重启服务: rc-service xray restart"
echo "停止服务: rc-service xray stop"
echo "=========================================="