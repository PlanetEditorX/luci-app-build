#!/bin/sh

log() {
    logger -t "keepalived-ha-failover_watchdog" "$1"
}

# 添加PID文件控制
PID_FILE="/var/run/failover_watchdog.pid"

# 如果 PID 文件存在
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if [ "$OLD_PID" != "$$" ]; then
        if kill -0 "$OLD_PID" 2>/dev/null; then
            log "发现旧监控脚本正在运行（PID: $OLD_PID），尝试终止"
            kill "$OLD_PID" 2>/dev/null
            sleep 1
            if kill -0 "$OLD_PID" 2>/dev/null; then
                log "旧进程未成功终止，强制杀掉"
                kill -9 "$OLD_PID" 2>/dev/null
            fi
            log "旧进程已清除，准备启动新实例"
        else
            log "发现无效 PID 文件，清理 $PID_FILE"
        fi
        rm -f "$PID_FILE"
    else
        log "PID 文件中的进程就是当前脚本（PID: $$），无需终止"
    fi
fi

# 写入当前进程 PID
echo $$ > "$PID_FILE"

# 设置退出清理
trap "rm -f $PID_FILE" EXIT

log "监控脚本已启动（PID: $$）"


# 变量将由init.d脚本动态替换
VIP="@VIP@"
ROLE="@ROLE@"
INTERFACE="@INTERFACE@"
CHECK_IP="@CHECK_IP@"
FAIL_THRESHOLD=@FAIL_THRESHOLD@
RECOVER_THRESHOLD=@RECOVER_THRESHOLD@
CHECK_INTERVAL=@CHECK_INTERVAL@

LOG="/tmp/log/failover_watchdog.log"
FAIL_COUNT=0
RECOVER_COUNT=0
MAX_SIZE=1048576 # 1MB

log "[Watchdog] 启动监控脚本..."

rotate_log() {
    if [ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -ge "$MAX_SIZE" ]; then
        tail -n 20 "$LOG" > "$LOG"
        log "[Watchdog] 日志已清理，保留最近 20 行"
    fi
}

check_peer_alive() {
    local ip="$1"
    local port="$2"
    local timeout_sec="${3:-1}"  # 默认超时 1 秒
    local name="$4"

    # Ping 检测
    if ! ping -c 1 -W "$timeout_sec" -n -q "$ip" >/dev/null 2>&1; then
        log "[Watchdog] $name $ip ping 不通"
        return 1
    fi

    # 端口检测（使用 bash 的 /dev/tcp）
    if ! timeout "$timeout_sec" bash -c "echo > /dev/tcp/$ip/$port" >/dev/null 2>&1; then
        log "[Watchdog] $name $ip:$port 端口不可达"
        return 1
    fi

    log "[Watchdog] $name $ip:$port 在线"
    return 0
}

while true; do
    if [ "$ROLE" = "main" ]; then
        CHECK_NAME="从路由"
        if check_peer_alive "$CHECK_IP" 9090 1 "$CHECK_NAME"; then
            FAIL_COUNT=0
            RECOVER_COUNT=$((RECOVER_COUNT + 1))

            if ip -4 addr show "$INTERFACE" | grep -q "$VIP" && [ "$RECOVER_COUNT" -ge "$RECOVER_THRESHOLD" ]; then
                log "[Watchdog] $CHECK_NAME 恢复，解绑 VIP $VIP"
                ip addr del "$VIP/24" dev "$INTERFACE"
                RECOVER_COUNT=0
                log "[Watchdog] 关闭主路由openclash"
                /etc/init.d/openclash stop
                uci set openclash.config.enable='0'
                uci commit openclash
            fi
        else
            RECOVER_COUNT=0
            FAIL_COUNT=$((FAIL_COUNT + 1))

            if ! ip -4 addr show "$INTERFACE" | grep -q "$VIP" && [ "$FAIL_COUNT" -ge "$FAIL_THRESHOLD" ]; then
                log "[Watchdog] 接管 VIP $VIP"
                ip addr add "$VIP/24" dev "$INTERFACE"
                FAIL_COUNT=0
                log "[Watchdog] 启动主路由openclash"
                uci set openclash.config.enable='1'
                uci commit openclash
                /etc/init.d/openclash start
            fi
        fi

    else
        CHECK_NAME="主路由"
        if ping -c 1 -W 1 -n -q "$CHECK_IP" >/dev/null 2>&1; then
            log "[Watchdog] $CHECK_NAME $CHECK_IP 在线"
        else
            log "[Watchdog] $CHECK_NAME $CHECK_IP 失联"
        fi
    fi

    rotate_log
    sleep "$CHECK_INTERVAL"
done