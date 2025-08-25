#!/bin/sh

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> /tmp/log/failover_watchdog.log
    logger -t "keepalived-ha-failover_watchdog" "$1"
}

# 添加PID文件控制
PID_FILE="/var/run/failover_watchdog.pid"
VIP_BOUND=true

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
    (
        flock -n 9 || exit 1
        if [ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -ge "$MAX_SIZE" ]; then
            tail -n 20 "$LOG" > "$LOG"
            log "[Watchdog] 日志已清理，保留最近 20 行"
        fi
    ) 9>/var/lock/failover_watchdog.log.lock
}

# 检测从路由是否在线
check_peer_alive() {
    echo "开始检测: $1:$2" >&2
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

is_openclash_running() {
    pgrep -f openclash >/dev/null 2>&1
}

while true; do
    # 启动时检测 VIP 是否已绑定
    if ip -4 addr show "$INTERFACE" | grep -qw "$VIP"; then
        VIP_BOUND=true
    else
        VIP_BOUND=false
    fi
    if [ "$ROLE" = "main" ]; then
        CHECK_NAME="从路由"
        # 从路由在线
        if check_peer_alive "$CHECK_IP" 9090 1 "$CHECK_NAME"; then
            FAIL_COUNT=0
            RECOVER_COUNT=$((RECOVER_COUNT + 1))
            # 当检测网口有VIP后，检测从路由的状态，大于指定次数后解绑VIP
            if ip -4 addr show "$INTERFACE" | grep -qw "$VIP" && [ "$VIP_BOUND" = true ] && [ "$RECOVER_COUNT" -ge "$RECOVER_THRESHOLD" ]; then
                log "[Watchdog] 检测到 $CHECK_NAME 恢复，进行最终确认..."

                final_check=true
                for i in $(seq 1 3); do
                    if ! check_peer_alive "$CHECK_IP" 9090 1 "$CHECK_NAME"; then
                        final_check=false
                        break
                    fi
                    sleep 1  # 可选：稍微间隔一下，避免瞬时误判
                done

                if [ "$final_check" = true ]; then
                    log "[Watchdog] $CHECK_NAME 恢复，解绑 VIP $VIP"
                    ip addr del "$VIP/24" dev "$INTERFACE"
                    VIP_BOUND=false
                    RECOVER_COUNT=0

                    if is_openclash_running; then
                        log "[Watchdog] 关闭主路由openclash"
                        /etc/init.d/openclash stop
                        uci set openclash.config.enable='0'
                        uci commit openclash
                    fi
                else
                    log "[Watchdog] 检测到 $CHECK_NAME 恢复，但最终确认失败，重新进行测试..."
                    RECOVER_COUNT=0
                fi
            fi
        else
            RECOVER_COUNT=0
            FAIL_COUNT=$((FAIL_COUNT + 1))
            log "[Watchdog] 故障计数：FAIL_COUNT=$FAIL_COUNT, 阈值=$FAIL_THRESHOLD"
            # 新增调试日志
            log "[Watchdog] VIP检测结果：$(ip -4 addr show "$INTERFACE" | grep "$VIP" || echo "未找到")"
            log "[Watchdog] 接管条件是否满足：$(
            if ! ip -4 addr show "$INTERFACE" | grep -qw "$VIP" && [ "$FAIL_COUNT" -ge "$FAIL_THRESHOLD" ]; then
                echo "是"
            else
                echo "否"
            fi
            )"
            log "[Watchdog] 故障计数：FAIL_COUNT=$FAIL_COUNT, 阈值=$FAIL_THRESHOLD"  # 新增日志
            if ! ip -4 addr show "$INTERFACE" | grep -qw "$VIP" && [ "$FAIL_COUNT" -ge "$FAIL_THRESHOLD" ]; then
                log "[Watchdog] 接管 VIP $VIP"
                ip addr add "$VIP/24" dev "$INTERFACE"
                VIP_BOUND=true
                FAIL_COUNT=0
                if ! is_openclash_running; then
                    log "[Watchdog] 启动主路由openclash"
                    uci set openclash.config.enable='1'
                    uci commit openclash
                    /etc/init.d/openclash start
                fi
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