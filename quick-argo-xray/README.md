# Quick-Argo-Xray

一个专为 **64MB / 128MB** 内存环境（如 Alpine Linux, Debian, Ubuntu）优化的全自动部署脚本。通过 Xray-core 与 Cloudflare Argo Tunnel 的组合，实现低资源占用下的高效穿透。

## 🚀 特性

* **极简部署**：一行命令，全自动完成环境判断、核心下载与服务启动。
* **内存优化**：精简 Xray 配置，关闭所有非必要日志，实测可在 64MB RAM 环境稳定运行。
* **双模式输出**：自动生成 TLS (443) 与 非 TLS (80) 链接，适配不同使用场景。
* **智能重连**：内置 15 秒超时自愈逻辑，自动重启卡死的 Argo 隧道。
* **优选域名**：默认集成优选域名地址 `cdns.doon.eu.org`，提升连接稳定性。

## 🛠️ 快速开始

在终端中执行以下命令（请确保已上传脚本文件并赋予执行权限）：

```bash
bash <(curl -fsSL https://github.com/clerzg/vpstool/raw/refs/heads/main/quick-argo-xray/quick-argo-xray.sh)
```

## 📋 运行逻辑

1. **环境清理**：自动清理旧的残留文件，防止磁盘溢出。
2. **核心获取**：根据系统架构（amd64/arm64）自动获取最新版 Xray-core 与 Cloudflared。
3. **配置生成**：随机生成端口、UUID 和路径，配置 VLESS + WS 传输协议。
4. **服务监控**：实时监控隧道状态，并在部署成功后输出节点链接。

## 📝 输出示例

部署成功后，链接将显示在屏幕上并保存至 `v2ray.txt`：

```text
TLS:
vless://uuid@cdns.doon.eu.org:443?encryption=none&security=tls&type=ws&host=your-domain.trycloudflare.com&path=/path#ISP_TLS

NoTLS:
vless://uuid@cdns.doon.eu.org:80?encryption=none&security=none&type=ws&host=your-domain.trycloudflare.com&path=/path#ISP_NoTLS
```

## ⚠️ 注意事项

* **Alpine 用户**：请确保系统已安装 `curl` 和 `unzip` 以保证脚本正常运行。
* **资源占用**：本脚本已将日志等级设为 `none`，非常适合极其廉价的 VPS 长期挂机。

---

**免责声明**：本工具仅供网络技术研究与学习使用。
