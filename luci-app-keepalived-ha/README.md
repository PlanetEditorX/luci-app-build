# LuCI App: Keepalived HA

用于 OpenWrt/ImmortalWrt 的主路由高可用漂移控制，支持从路由故障检测、VIP 接管、OpenClash 控制等。

## 功能
- 支持 VRRP 虚拟 IP 漂移
- 支持从路由健康检测（ping）
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

## 文件结构
```bash
package/luci-app-keepalived-ha/
├── Makefile                      # 编译规则文件
└── files/
    ├── etc/
    │   ├── config/               # UCI配置文件
    │   │   └── keepalived-ha
    │   ├── init.d/               # 服务控制脚本
    │   │   └── keepalived-ha
    │   └── keepalived/           # 核心脚本目录
    │       ├── failover_watchdog.sh  # 主路由监控脚本
    │       ├── vip_up.sh             # 从路由VIP绑定脚本
    │       ├── vip_down.sh           # 从路由VIP解绑脚本
    │       └── template/             # 配置模板
    │           ├── keepalived_main.conf  # 主路由keepalived模板
    │           └── keepalived_peer.conf  # 从路由keepalived模板
    └── usr/
        └── lib/
            └── lua/
                └── luci/
                    ├── controller/   # 页面控制器
                    │   └── keepalived-ha.lua
                    ├── model/        # 配置数据模型
                    │   └── cbi/
                    │       └── keepalived-ha.lua
                    └── view/         # 页面模板
                        └── keepalived-ha/
                            └── status.htm

```