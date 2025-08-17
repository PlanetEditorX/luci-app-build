# LuCI App: Keepalived HA

用于 OpenWrt/ImmortalWrt 的主路由高可用漂移控制，支持旁路由故障检测、VIP 接管、OpenClash 控制等。

## 功能
- 支持 VRRP 虚拟 IP 漂移
- 支持旁路由健康检测（ping）
- 故障自动接管 VIP
- 恢复自动释放 VIP
- 控制 OpenClash 启停
- LuCI 页面配置与状态展示

## 适配平台
- ImmortalWrt MT7981 (RAX3000M eMMC)

## 构建方式
使用 GitHub Actions 自动生成 `.ipk` 包，或本地使用 SDK 编译。

## 安装方式
```bash
opkg install luci-app-keepalived-ha_*.ipk
