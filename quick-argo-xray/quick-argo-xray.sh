#!/bin/bash

function quicktunnel(){
echo "正在初始化环境..."
rm -rf xray cloudflared-linux xray.zip argo.log v2ray.txt
case "$(uname -m)" in
    x86_64 | x64 | amd64 ) ARCH_XRAY="Xray-linux-64.zip"; ARCH_CF="cloudflared-linux-amd64" ;;
    arm64 | aarch64 ) ARCH_XRAY="Xray-linux-arm64-v8a.zip"; ARCH_CF="cloudflared-linux-arm64" ;;
    * ) echo "错误：不支持的架构"; exit 1 ;;
esac

echo "正在获取网络信息..."
trace_raw=$(curl -s --connect-timeout 5 https://www.cloudflare.com/cdn-cgi/trace)
loc=$(echo "$trace_raw" | grep "loc=" | cut -d= -f2)
ip_addr=$(echo "$trace_raw" | grep "ip=" | cut -d= -f2)
isp="${loc:-Argo}-${ip_addr:-Node}"

echo "正在全速下载核心组件 (Xray & Cloudflared)..."
mkdir -p xray
curl -L -o xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/${ARCH_XRAY}
unzip -j xray.zip xray -d xray && rm -f xray.zip
curl -L -o cloudflared-linux https://github.com/cloudflare/cloudflared/releases/latest/download/${ARCH_CF}
chmod +x cloudflared-linux xray/xray

uuid=$(cat /proc/sys/kernel/random/uuid)
urlpath=$(echo $uuid | awk -F- '{print $1}')
port=$[$RANDOM+10000]

cat > xray/config.json <<EOF
{"log":{"level":"none"},"inbounds":[{"port":$port,"listen":"127.0.0.1","protocol":"vless","settings":{"decryption":"none","clients":[{"id":"$uuid"}]},"streamSettings":{"network":"ws","wsSettings":{"path":"/$urlpath"}}}],"outbounds":[{"protocol":"freedom"}]}
EOF

echo "正在建立隧道连接，请稍候..."
./xray/xray run -c xray/config.json >/dev/null 2>&1 &
./cloudflared-linux tunnel --url http://127.0.0.1:$port --no-autoupdate --protocol http2 >argo.log 2>&1 &

n=0
while true; do
    n=$[$n+1]
    echo -ne "\r已等待: ${n}s (通常 5-15s 成功)..."
    
    argo=$(grep -o 'https://[-a-z0-9.]*trycloudflare.com' argo.log | awk -F// '{print $2}')
    
    if [ $n -eq 15 ] && [ -z "$argo" ]; then
        n=0
        echo -e "\n连接超时，正在尝试重启隧道..."
        pkill -9 cloudflared-linux
        ./cloudflared-linux tunnel --url http://127.0.0.1:$port --no-autoupdate --protocol http2 >argo.log 2>&1 &
    elif [ -n "$argo" ]; then
        rm -rf argo.log
        echo -e "\n\n🚀 部署成功！"
        L_TLS="vless://$uuid@cdns.doon.eu.org:443?encryption=none&security=tls&type=ws&host=$argo&path=%2F$urlpath#${isp}_TLS"
        L_NTLS="vless://$uuid@cdns.doon.eu.org:80?encryption=none&security=none&type=ws&host=$argo&path=%2F$urlpath#${isp}_NoTLS"
        
        echo -e "----------------------------------------"
        echo -e "TLS 链接 (推荐):\n$L_TLS\n"
        echo -e "非 TLS 链接:\n$L_NTLS"
        echo -e "----------------------------------------"
        echo -e "配置已保存至: v2ray.txt"
        
        echo -e "TLS:\n$L_TLS\n\nNoTLS:\n$L_NTLS" > v2ray.txt
        break
    fi
    sleep 1
done
}

quicktunnel
