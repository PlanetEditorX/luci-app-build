#!/bin/sh
CONF_SRC="/etc/keepalived/keepalived.conf"
CONF_DST="/tmp/keepalived.conf"
KEEPALIVED_BIN="/usr/sbin/keepalived"
LOG="/tmp/log/keepalived_boot_main.log"

echo "== keepalived_boot.sh 被调用 ==" >> "$LOG"

if [ -f "$CONF_SRC" ]; then
    cp "$CONF_SRC" "$CONF_DST"
    echo "[INFO] 配置文件已复制到 $CONF_DST" >> "$LOG"
else
    echo "[ERROR] 配置文件不存在：$CONF_SRC" >> "$LOG"
    exit 1
fi

"$KEEPALIVED_BIN" -n -f "$CONF_DST" &
echo "[INFO] Keepalived 已启动" >> "$LOG"

/etc/keepalived/failover_watchdog.sh &
echo "[INFO] Watchdog 已启动" >> "$LOG"
