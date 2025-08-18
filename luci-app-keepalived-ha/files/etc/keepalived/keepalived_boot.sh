#!/bin/sh
CONF_SRC="/etc/keepalived/keepalived.conf"
CONF_DST="/tmp/keepalived.conf"
KEEPALIVED_BIN="/usr/sbin/keepalived"
LOG="/tmp/log/keepalived_boot.log"

# 从配置文件提取VIP和接口信息
VIP=$(awk '/virtual_ipaddress {/{getline; gsub(/[ \t;]/, "", $0); print $0; exit}' "$CONF_SRC")
INTERFACE=$(awk '/interface/{gsub(/[ \t;]/, "", $2); print $2; exit}' "$CONF_SRC")

echo "== keepalived_boot.sh 被调用 ==" >> "$LOG"
echo "[INFO] 从配置提取 - VIP: $VIP, 接口: $INTERFACE" >> "$LOG"

if [ -f "$CONF_SRC" ]; then
    cp "$CONF_SRC" "$CONF_DST"
    echo "[INFO] 配置文件已复制到 $CONF_DST" >> "$LOG"
else
    echo "[ERROR] 配置文件不存在：$CONF_SRC" >> "$LOG"
    exit 1
fi

# 停止已运行的keepalived进程
pkill -f "$KEEPALIVED_BIN" >/dev/null 2>&1
sleep 1

"$KEEPALIVED_BIN" -n -f "$CONF_DST" &
echo "[INFO] Keepalived 已启动" >> "$LOG"

sleep 2

# 检查VIP绑定状态
if ip addr show "$INTERFACE" | grep -q "$VIP"; then
    echo "[INFO] VIP $VIP 已绑定到 $INTERFACE" >> "$LOG"
else
    echo "[WARN] VIP $VIP 未绑定，尝试手动绑定" >> "$LOG"
    # 使用配置文件中的子网掩码（默认/24，可根据实际情况调整）
    ip addr add "$VIP"/24 dev "$INTERFACE" &&
        echo "[INFO] VIP 手动绑定成功" >> "$LOG" ||
        echo "[ERROR] VIP 手动绑定失败" >> "$LOG"
fi