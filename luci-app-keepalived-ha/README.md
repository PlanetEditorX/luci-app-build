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
- s922x docker容器

## 构建方式
使用 GitHub Actions 自动生成 `.ipk` 包，或本地使用 SDK 编译。

## 安装方式
- ImmortalWrt MT7981
```bash
opkg install luci-app-keepalived-ha_1.0-r1_mt798x.ipk
```
- s922x docker
```bash
opkg install luci-app-keepalived-ha_1.0-r1_filogic.ipk
```

## 文件结构
```bash
luci-app-keepalived-ha/
├── Makefile                             # 编译规则文件，定义包信息、依赖、安装文件路径及安装后脚本
└── files
    ├── etc/
    │   ├── config/                      # UCI配置文件目录
    │   │   └── keepalived-ha            # 存储keepalived-ha的UCI配置信息
    │   ├── init.d/                      # 服务控制脚本目录
    │   │   ├── failover_watchdog        # 路由监控服务控制脚本，用于管理监控进程的启停等
    │   │   └── keepalived-ha            # keepalived-ha主服务控制脚本，负责服务的启用、禁用、启动、停止等
    │   └── keepalived/                  # 核心脚本目录
    │       ├── keepalived-ha-debug.sh   # 调试脚本，用于检查配置文件、提取参数、查看接口和进程状态等
    │       ├── vip_manager.sh           # VIP管理脚本，实现VIP的绑定、解绑和状态检查功能
    │       └── template/                # 配置模板目录
    │           ├── failover_watchdog.sh # 主路由监控脚本模板，包含监控逻辑、故障检测与恢复处理等
    │           ├── keepalived_main.conf # 主路由keepalived配置模板，定义主路由的VRRP等相关配置
    │           ├── keepalived_peer.conf # 从路由keepalived配置模板，定义从路由的VRRP等相关配置
    │           ├── vip_up.sh            # 从路由VIP绑定脚本模板，用于从路由绑定VIP时执行
    │           └── vip_down.sh          # 从路由VIP解绑脚本模板，用于从路由解绑VIP时执行
    └── usr/
        └── lib/
            └── lua/
                └── luci/
                    ├── controller/                   # 页面控制器目录
                    │   └── keepalived-ha.lua         # 控制LuCI页面的路由和访问逻辑
                    ├── model/                        # 配置数据模型目录
                    │   └── cbi/
                    │       └── keepalived-ha/
                    │           └── keepalived-ha.lua # 定义LuCI页面的配置表单和数据处理逻辑
                    └── view/                         # 页面模板目录
                        └── keepalived-ha/
                            └── status.htm            # (暂未使用)状态页面模板，用于展示keepalived-ha的运行状态信息
```