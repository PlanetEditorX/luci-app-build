#!/bin/sh

# 变量将由init.d脚本动态替换
VIP="@VIP@"
INTERFACE="@INTERFACE@"
PEER_IP="@PEER_IP@"
FAIL_THRESHOLD=@FAIL_THRESHOLD@
RECOVER_THRESHOLD=@RECOVER_THRESHOLD@
CHECK_INTERVAL=@CHECK_INTERVAL@

LOG="/tmp/log/failover_watchdog.log"
FAIL_COUNT=0
RECOVER_COUNT=0
MAX_SIZE=1048576 # 1MB

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

log "[Watchdog] 启动监控脚本..."

rotate_log() {
    if [ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -ge "$MAX_SIZE" ]; then
        tail -n 20 "$LOG" > "$LOG"
        log "[Watchdog] 日志已清理，保留最近 20 行"
    fi
}

while true; do
    if ping -c 1 -W 1 -n -q "$PEER_IP" >/dev/null 2>&1; then
        log "[Watchdog] 旁路由 $PEER_IP 在线"
        FAIL_COUNT=0
        RECOVER_COUNT=$((RECOVER_COUNT + 1))

        if ip -4 addr show "$INTERFACE" | grep -q "$VIP" && [ "$RECOVER_COUNT" -ge "$RECOVER_THRESHOLD" ]; then
            log "[Watchdog] 旁路由恢复，解绑 VIP $VIP"
            ip addr del "$VIP/32" dev "$INTERFACE"
            RECOVER_COUNT=0
            log "[Watchdog] 关闭主路由openclash"
            /etc/init.d/openclash stop
            uci set openclash.config.enable='0'
            uci commit openclash
        fi
    else
        log "[Watchdog] 旁路由 $PEER_IP 失联"
        RECOVER_COUNT=0
        FAIL_COUNT=$((FAIL_COUNT + 1))

        if ! ip -4 addr show "$INTERFACE" | grep -q "$VIP" && [ "$FAIL_COUNT" -ge "$FAIL_THRESHOLD" ]; then
            log "[Watchdog] 接管 VIP $VIP"
            ip addr add "$VIP/32" dev "$INTERFACE"
            FAIL_COUNT=0
            log "[Watchdog] 启动主路由openclash"
            uci set openclash.config.enable='1'
            uci commit openclash
            /etc/init.d/openclash start
        fi
    fi

    rotate_log
    sleep "$CHECK_INTERVAL"
done