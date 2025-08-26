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

---

### 一键部署脚本

#### 🛠️ 主路由一键部署脚本
主路由的角色是 **MASTER**，只在从路由失效时接管 VIP


保存为 `/etc/script/deploy_ha_main.sh`：

```bash
mkdir -p /etc/script && nano /etc/script/deploy_ha_main.sh && chmod +x /etc/script/deploy_ha_main.sh && sh /etc/script/deploy_ha_main.sh
```

```sh
#!/bin/sh

### === 用户配置区域 === ###
VIP="192.168.1.5"
INTERFACE="br-lan"
PRIORITY="50"
PEER_IP="192.168.1.3"
FAIL_THRESHOLD=3
RECOVER_THRESHOLD=2
CHECK_INTERVAL=5
### ===================== ###

echo "[HA-Main] 开始部署主路由高可用配置..."

### 1. 系统参数
grep -q '^net.ipv4.ip_nonlocal_bind=1$' /etc/sysctl.conf || echo 'net.ipv4.ip_nonlocal_bind=1' >> /etc/sysctl.conf
sysctl -p

### 2. nftables 防火墙
cat <<EOF > /etc/nftables.conf
table inet filter {
    chain input {
        type filter hook input priority 0; policy accept;

        ct state established,related accept
        iifname "lo" accept
        ip protocol icmp accept
        ip protocol 112 accept  # VRRP
    }
}
EOF
nft -f /etc/nftables.conf
echo "[HA-Main] nftables 配置完成"

### 3. Keepalived 配置
mkdir -p /etc/keepalived

cat <<EOF > /etc/keepalived/keepalived.conf
vrrp_instance VI_1 {
    state BACKUP
    interface $INTERFACE
    virtual_router_id 51
    priority $PRIORITY
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        $VIP
    }
}
EOF

### 4. 漂移检测脚本（嵌入变量）
cat <<EOF > /etc/keepalived/failover_watchdog.sh
#!/bin/sh

VIP="$VIP"
INTERFACE="$INTERFACE"
PEER_IP="$PEER_IP"
FAIL_THRESHOLD=$FAIL_THRESHOLD
RECOVER_THRESHOLD=$RECOVER_THRESHOLD
CHECK_INTERVAL=$CHECK_INTERVAL

LOG="/tmp/log/failover_watchdog.log"
FAIL_COUNT=0
RECOVER_COUNT=0
MAX_SIZE=1048576 # 1MB

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] \$1" >> "\$LOG"
}

log "[Watchdog] 启动监控脚本..."

rotate_log() {
    if [ -f "\$LOG" ] && [ "\$(wc -c < "\$LOG")" -ge "\$MAX_SIZE" ]; then
        tail -n 20 "\$LOG" > "\$LOG"
        log "[Watchdog] 日志已清理，保留最近 20 行"
    fi
}

while true; do
    if ping -c 1 -W 1 -n -q "\$PEER_IP" >/dev/null 2>&1; then
        log "[Watchdog] 从路由 \$PEER_IP 在线"
        FAIL_COUNT=0
        RECOVER_COUNT=\$((RECOVER_COUNT + 1))

        if ip -4 addr show "\$INTERFACE" | grep -q "\$VIP" && [ "\$RECOVER_COUNT" -ge "\$RECOVER_THRESHOLD" ]; then
            log "[Watchdog] 从路由恢复，解绑 VIP \$VIP"
            ip addr del "\$VIP/32" dev "\$INTERFACE"
            RECOVER_COUNT=0
            log "[Watchdog] 关闭主路由openclash"
            /etc/init.d/openclash stop
            uci set openclash.config.enable='0'
            uci commit openclash
        fi
    else
        log "[Watchdog] 从路由 \$PEER_IP 失联"
        RECOVER_COUNT=0
        FAIL_COUNT=\$((FAIL_COUNT + 1))

        if ! ip -4 addr show "\$INTERFACE" | grep -q "\$VIP" && [ "\$FAIL_COUNT" -ge "\$FAIL_THRESHOLD" ]; then
            log "[Watchdog] 接管 VIP \$VIP"
            ip addr add "\$VIP/32" dev "\$INTERFACE"
            FAIL_COUNT=0
            log "[Watchdog] 启动主路由openclash"
            uci set openclash.config.enable='1'
            uci commit openclash
            /etc/init.d/openclash start
            uci set openclash.config.enable='0'
            uci commit openclash
        fi
    fi

    rotate_log
    sleep "\$CHECK_INTERVAL"
done
EOF

chmod +x /etc/keepalived/failover_watchdog.sh

### 5. 自动启动脚本
cat <<EOF > /etc/keepalived/keepalived_boot.sh
#!/bin/sh
CONF_SRC="/etc/keepalived/keepalived.conf"
CONF_DST="/tmp/keepalived.conf"
KEEPALIVED_BIN="/usr/sbin/keepalived"
LOG="/tmp/log/keepalived_boot_main.log"

echo "== keepalived_boot.sh 被调用 ==" >> "\$LOG"

if [ -f "\$CONF_SRC" ]; then
    cp "\$CONF_SRC" "\$CONF_DST"
    echo "[INFO] 配置文件已复制到 \$CONF_DST" >> "\$LOG"
else
    echo "[ERROR] 配置文件不存在：\$CONF_SRC" >> "\$LOG"
    exit 1
fi

"\$KEEPALIVED_BIN" -n -f "\$CONF_DST" &
echo "[INFO] Keepalived 已启动" >> "\$LOG"

/etc/keepalived/failover_watchdog.sh &
echo "[INFO] Watchdog 已启动" >> "\$LOG"
EOF

chmod +x /etc/keepalived/keepalived_boot.sh

### 6. 添加到 rc.local
sed -i '/keepalived_boot.sh/d' /etc/rc.local
sed -i '/exit 0/i /etc/keepalived/keepalived_boot.sh' /etc/rc.local
echo "[HA-Main] 已添加开机启动"

### 7. 可选：封装为 init.d 服务（OpenWrt/ImmortalWrt）
cat <<EOF > /etc/init.d/failover_watchdog
#!/bin/sh /etc/rc.common
START=99

start() {
    echo "[init.d] 启动 failover_watchdog"
    /etc/keepalived/failover_watchdog.sh &
}
EOF

chmod +x /etc/init.d/failover_watchdog
/etc/init.d/failover_watchdog enable

echo "[HA-Main] 主路由部署完成 ✅ 请重启设备验证 VIP 漂移逻辑是否生效"
```

---

## ✅ 使用方法

```sh
sh /etc/script/deploy_ha_main.sh
```

---

## 🧪 验证主路由是否接管 VIP

1. 启动从路由，确认 VIP 在从路由上绑定
2. `killall keepalived` 或断电从路由
3. 主路由应自动接管 VIP（通过 VRRP）

验证：

```bash
tcpdump -i br-lan vrrp
```
```sh
ip addr show br-lan | grep 192.168.1.5
logread -f | grep keepalived
```

---

#### 从路由一键部署脚本
##### 🛠️ 脚本路径建议

保存为 `/etc/script/deploy_ha_proxy.sh`：
```bash
mkdir -p /etc/script && nano /etc/script/deploy_ha_proxy.sh && chmod +x /etc/script/deploy_ha_proxy.sh && sh /etc/script/deploy_ha_proxy.sh
```

```sh
#!/bin/sh

### === 用户配置区域 === ###
VIP="192.168.1.5"
MAIN_ROUTER="192.168.1.2"
PROXY_ROUTER="192.168.1.3"
INTERFACE="eth0"
### ===================== ###

echo "[HA-Deploy] 开始部署从路由高可用架构..."

### 1. 系统参数
echo "net.ipv4.ip_nonlocal_bind=1" >> /etc/sysctl.conf
sysctl -p

### 2. nftables 防火墙
cat <<EOF > /etc/nftables.conf
table inet filter {
    chain input {
        type filter hook input priority 0; policy accept;
        ct state established,related accept
        iifname "lo" accept
        ip protocol icmp accept
        ip protocol 112 accept  # VRRP
    }
}
EOF
nft -f /etc/nftables.conf
echo "[HA-Deploy] nftables 配置完成"

### 3. Keepalived 配置
mkdir -p /etc/keepalived

cat <<EOF > /etc/keepalived/keepalived.conf
vrrp_instance VI_1 {
    state MASTER
    interface $INTERFACE
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        $VIP
    }
    notify_master "/etc/keepalived/vip_up.sh"
    notify_backup "/etc/keepalived/vip_down.sh"
    notify_fault "/etc/keepalived/vip_down.sh"
}
EOF

### 4. VIP 漂移脚本
cat <<EOF > /etc/keepalived/vip_up.sh
#!/bin/sh
logger -t keepalived "VIP $VIP 已绑定，从路由接管"
ip addr add $VIP/24 dev $INTERFACE
EOF

cat <<EOF > /etc/keepalived/vip_down.sh
#!/bin/sh
logger -t keepalived "VIP $VIP 已解绑，回退主路由"
ip addr del $VIP/24 dev $INTERFACE
EOF

chmod +x /etc/keepalived/vip_*.sh
echo "[HA-Deploy] VIP 漂移脚本已配置"

### 5. 自动启动脚本
cat <<EOF > /etc/keepalived/keepalived_boot.sh
#!/bin/sh
CONF_SRC="/etc/keepalived/keepalived.conf"
CONF_DST="/tmp/log/keepalived.conf"
KEEPALIVED_BIN="/usr/sbin/keepalived"
LOG="/tmp/log/keepalived_boot.log"

echo "== keepalived_boot.sh 被调用 ==" >> "\$LOG"

if [ -f "\$CONF_SRC" ]; then
    cp "\$CONF_SRC" "\$CONF_DST"
    echo "[INFO] 配置文件已复制到 \$CONF_DST" >> "\$LOG"
else
    echo "[ERROR] 配置文件不存在：\$CONF_SRC" >> "\$LOG"
    exit 1
fi

"\$KEEPALIVED_BIN" -n -f "\$CONF_DST" &
echo "[INFO] Keepalived 已启动" >> "\$LOG"

sleep 2

if ip addr show "$INTERFACE" | grep -q "$VIP"; then
    echo "[INFO] VIP $VIP 已绑定" >> "\$LOG"
else
    echo "[WARN] VIP $VIP 未绑定，尝试手动绑定" >> "\$LOG"
    ip addr add "$VIP"/24 dev "$INTERFACE" && \
    echo "[INFO] VIP 手动绑定成功" >> "\$LOG" || \
    echo "[ERROR] VIP 手动绑定失败" >> "\$LOG"
fi
EOF

chmod +x /etc/keepalived/keepalived_boot.sh

### 6. 添加到 rc.local
sed -i '/keepalived_boot.sh/d' /etc/rc.local
sed -i '/exit 0/i /etc/keepalived/keepalived_boot.sh' /etc/rc.local
echo "[HA-Deploy] 已添加开机启动"
echo "[HA-Deploy] 部署完成 ✅ 请重启设备验证 VIP 是否绑定成功"
```

---

## 🧪 重启后验证

```sh
cat /tmp/log/keepalived_boot.log
ip addr show eth0 | grep 192.168.1.5
logread -f | grep keepalived
```

---
