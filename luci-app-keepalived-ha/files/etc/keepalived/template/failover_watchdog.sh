#!/bin/bash

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> /tmp/log/failover_watchdog.log
    logger -t "keepalived-ha [Watchdog]" "$1"
}

# PID文件控制
PID_FILE="/var/run/failover_watchdog.pid"
VIP_BOUND=true
MAX_FAIL_COUNT=50
VRRP_MONITOR_PID=0

# 清理旧进程
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if [ "$OLD_PID" != "$$" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        log "发现旧监控脚本正在运行（PID: $OLD_PID），尝试终止"
        kill "$OLD_PID" 2>/dev/null
        sleep 1
        if kill -0 "$OLD_PID" 2>/dev/null; then
            kill -9 "$OLD_PID" 2>/dev/null
            log "旧进程已强制终止"
        fi
    fi
    rm -f "$PID_FILE"
fi
echo $$ > "$PID_FILE"
trap "rm -f $PID_FILE; [ $VRRP_MONITOR_PID -ne 0 ] && kill $VRRP_MONITOR_PID 2>/dev/null" EXIT

# 配置参数（会被init.d脚本动态替换）
VIP="@VIP@"
ROLE="@ROLE@"
INTERFACE="@INTERFACE@"
CHECK_IP="@CHECK_IP@"
FAIL_THRESHOLD=@FAIL_THRESHOLD@
RECOVER_THRESHOLD=@RECOVER_THRESHOLD@
CHECK_INTERVAL=@CHECK_INTERVAL@
CONTROL_OPENCLASH=@CONTROL_OPENCLASH@

LOG="/tmp/log/failover_watchdog.log"
FAIL_COUNT=0
RECOVER_COUNT=0
MAX_SIZE=1048576
VRRP_STATUS="unknown"
LAST_VRRP_SRC=""
LAST_VRRP_PRIO=0

log "监控脚本已启动（PID: $$）"

# 日志轮转
rotate_log() {
    (
        flock -n 9 || exit 1
        if [ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -ge "$MAX_SIZE" ]; then
            tail -n 20 "$LOG" > "$LOG"
            log "日志已清理，保留最近 20 行"
        fi
    ) 9>/var/lock/failover_watchdog.log.lock
}

# VRRP报文监控函数
monitor_vrrp() {
    tcpdump -i "$INTERFACE" vrrp -n -l 2>/dev/null | awk -v logtag="keepalived-ha [VRRP]" '
    {
        # 提取源IP（兼容末尾带冒号的情况）
        src_ip = $3
        sub(/:/, "", src_ip)

        # 提取优先级：遍历字段找"prio"关键字，取其下一个字段
        prio = "unknown"
        for (i=1; i<=NF; i++) {
            if ($i == "prio") {
                prio = $(i+1)  # 优先级是"prio"的下一个字段
                sub(/,/, "", prio)  # 移除可能的逗号
                break
            }
        }

        # 输出到日志
        cmd = "echo \"[$(date +\"%Y-%m-%d %H:%M:%S\")] VRRP监控: " src_ip " 优先级 " prio "\" >> /tmp/log/failover_watchdog.log"
        system(cmd)
        cmd = "logger -t \"" logtag "\" \"" src_ip " 优先级 " prio "\""
        system(cmd)

        # 写入状态文件供主进程读取
        cmd = "echo \"" src_ip " " prio "\" > /tmp/keepalived_vrrp_status.tmp"
        system(cmd)
        cmd = "mv /tmp/keepalived_vrrp_status.tmp /tmp/keepalived_vrrp_status"
        system(cmd)
    }'
}

# 检查VRRP状态
check_vrrp_status() {
    if [ -f "/tmp/keepalived_vrrp_status" ]; then
        read -r LAST_VRRP_SRC LAST_VRRP_PRIO < /tmp/keepalived_vrrp_status
        # 验证优先级是否为数字（防止文件内容格式错误）
        if ! [[ "$LAST_VRRP_PRIO" =~ ^[0-9]+$ ]]; then
            VRRP_STATUS="invalid_data"
            log "VRRP状态: 无效的优先级数据（$LAST_VRRP_PRIO）"
            return
        fi

        if [ "$LAST_VRRP_PRIO" -eq 0 ]; then
            VRRP_STATUS="failed"
            log "VRRP状态: $LAST_VRRP_SRC 发生故障（优先级 0）"
        else
            # 主路由角色逻辑
            if [ "$ROLE" = "main" ]; then
                if [ "$LAST_VRRP_SRC" = "$CHECK_IP" ]; then
                    log "VRRP状态: 从路由 $LAST_VRRP_SRC 正常运行（优先级 $LAST_VRRP_PRIO）"
                    VRRP_STATUS="peer"
                else
                    log "VRRP状态: 主路由 $LAST_VRRP_SRC 正常运行（优先级 $LAST_VRRP_PRIO）"
                    VRRP_STATUS="main"
                fi
            # 从路由角色补充逻辑
            elif [ "$ROLE" = "peer" ]; then
                log "VRRP状态: 从路由 $LAST_VRRP_SRC 正常运行（优先级 $LAST_VRRP_PRIO）"
            fi
        fi
    else
        VRRP_STATUS="no_data"
        log "VRRP状态: 未收到报文"
    fi
}
# 检测节点在线状态
check_peer_alive() {
    local ip="$1"
    local port="$2"
    local timeout_sec="${3:-1}"
    local name="$4"

    # Ping检测
    if ! ping -c 1 -W "$timeout_sec" -n -q "$ip" >/dev/null 2>&1; then
        log "$name $ip ping 不通"
        return 1
    fi

    # 端口检测
    if ! timeout "$timeout_sec" bash -c "echo > /dev/tcp/$ip/$port" >/dev/null 2>&1; then
        log "$name $ip:$port 端口不可达"
        return 1
    fi

    log "$name $ip:$port 在线"
    return 0
}

# OpenClash状态检查
is_openclash_running() {
    pgrep -f openclash >/dev/null 2>&1 && \
    [ "$(uci get openclash.config.enable 2>/dev/null)" = "1" ]
}

# 启动VRRP监控进程
monitor_vrrp &
VRRP_MONITOR_PID=$!
log "VRRP监控进程已启动（PID: $VRRP_MONITOR_PID）"

# OpenClash 控制状态计数器
RECOVER_CONFIRM_COUNT=0
FAIL_CONFIRM_COUNT=0
LAST_OPENCLASH_ACTION=""

# 主循环
while true; do
    # 检查VIP绑定状态
    if ! ip -4 addr show "$INTERFACE" | grep -qw "$VIP"; then
        VIP_BOUND=false
    else
        VIP_BOUND=true
    fi

    # 检查VRRP状态
    check_vrrp_status

    if [ "$ROLE" = "main" ]; then
        CHECK_NAME="从路由"
        # # 结合VRRP状态和健康检查
        # if check_peer_alive "$CHECK_IP" 9090 1 "$CHECK_NAME"; then
        #     FAIL_COUNT=0
        #     RECOVER_COUNT=$((RECOVER_COUNT + 1))
        #     log "test-1"
        #     log "VIP_BOUND: $VIP_BOUND; RECOVER_COUNT: $RECOVER_COUNT; RECOVER_THRESHOLD: $RECOVER_THRESHOLD"
        #     # 从路由恢复，解绑VIP
        #     if [ "$VIP_BOUND" = true ] && [ "$RECOVER_COUNT" -ge "$RECOVER_THRESHOLD" ] && [ "$VRRP_STATUS" = "peer" ]; then
        #         log "检测到 $CHECK_NAME 恢复，进行最终确认..."
        #         final_check=true
        #         for i in $(seq 1 3); do
        #             if ! check_peer_alive "$CHECK_IP" 9090 1 "$CHECK_NAME"; then
        #                 final_check=false
        #                 break
        #             fi
        #             sleep 1
        #         done

        #         if [ "$final_check" = true ]; then
        #             log "$CHECK_NAME 恢复，解绑 VIP $VIP"
        #             ip addr del "$VIP/24" dev "$INTERFACE"
        #             VIP_BOUND=false
        #             RECOVER_COUNT=0
        #         else
        #             log "最终确认失败，重新测试..."
        #             RECOVER_COUNT=0
        #         fi
        #     fi
        #     log "test-2"
        # else
        #     RECOVER_COUNT=0
        #     FAIL_COUNT=$((FAIL_COUNT + 1))

        #     if [ "$FAIL_COUNT" -ge "$MAX_FAIL_COUNT" ]; then
        #         log "FAIL_COUNT 达到最大值 $MAX_FAIL_COUNT，自动归零"
        #         FAIL_COUNT=0
        #     fi
        #     if [ "$VRRP_STATUS" = "peer" ];then
        #         log "检测到从路由上线，FAIL_COUNT自动归零"
        #         FAIL_COUNT=0
        #     fi
        #     log "故障计数：FAIL_COUNT=$FAIL_COUNT, 阈值=$FAIL_THRESHOLD"

        #     # 满足条件则接管VIP
        #     if [ "$VIP_BOUND" = false ] && [ "$FAIL_COUNT" -ge "$FAIL_THRESHOLD" ] && ( [ "$VRRP_STATUS" = "failed" ] || [ "$VRRP_STATUS" = "no_data" ] ); then
        #         log "接管 VIP $VIP"
        #         ip addr add "$VIP/24" dev "$INTERFACE"
        #         VIP_BOUND=true
        #         FAIL_COUNT=0
        #     fi
        # fi

        # 控制 OpenClash 的逻辑
        if [ "$CONTROL_OPENCLASH" = "1" ]; then
            if [ "$VRRP_STATUS" = "peer" ]; then
                if check_peer_alive "$CHECK_IP" 9090 1 "$CHECK_NAME"; then
                    RECOVER_CONFIRM_COUNT=$((RECOVER_CONFIRM_COUNT + 1))
                    FAIL_CONFIRM_COUNT=0

                    if [ "$RECOVER_CONFIRM_COUNT" -le 3 ]; then
                        log "从路由检测成功，RECOVER_CONFIRM_COUNT=$RECOVER_CONFIRM_COUNT"
                    elif [ "$RECOVER_CONFIRM_COUNT" -ge 500 ]; then
                        RECOVER_CONFIRM_COUNT=0
                        log "RECOVER_CONFIRM_COUNT 达到上限，已重置为 0"
                    fi

                    if [ "$RECOVER_CONFIRM_COUNT" -ge 3 ]; then
                        if is_openclash_running; then
                            log "关闭主路由 OpenClash（从路由稳定在线）"
                            /etc/init.d/openclash stop
                            uci set openclash.config.enable='0'
                            uci commit openclash
                            LAST_OPENCLASH_ACTION="stopped"
                            RECOVER_CONFIRM_COUNT=0  # 只有真正执行关闭时才重置
                        elif [ "$LAST_OPENCLASH_ACTION" != "stopped" ]; then
                            log "OpenClash 已关闭，无需操作"
                            LAST_OPENCLASH_ACTION="stopped"
                            RECOVER_CONFIRM_COUNT=0  # 仅在首次确认已关闭时重置
                        fi
                    fi
                else
                    RECOVER_CONFIRM_COUNT=0
                fi

            elif [ "$VRRP_STATUS" = "main" ] || [ "$VRRP_STATUS" = "failed" ]; then
                if ! is_openclash_running; then
                    FAIL_CONFIRM_COUNT=$((FAIL_CONFIRM_COUNT + 1))
                    RECOVER_CONFIRM_COUNT=0

                    if [ "$FAIL_CONFIRM_COUNT" -le 3 ]; then
                        log "从路由检测失败，FAIL_CONFIRM_COUNT=$FAIL_CONFIRM_COUNT"
                    elif [ "$FAIL_CONFIRM_COUNT" -ge 500 ]; then
                        FAIL_CONFIRM_COUNT=0
                        log "FAIL_CONFIRM_COUNT 达到上限，已重置为 0"
                    fi

                    if [ "$FAIL_CONFIRM_COUNT" -ge 3 ]; then
                        log "启动主路由 OpenClash（从路由稳定失联）"
                        uci set openclash.config.enable='1'
                        uci commit openclash
                        /etc/init.d/openclash start
                        LAST_OPENCLASH_ACTION="started"
                        FAIL_CONFIRM_COUNT=0
                    fi
                elif [ "$LAST_OPENCLASH_ACTION" != "started" ]; then
                    log "OpenClash 已在运行，无需启动"
                    LAST_OPENCLASH_ACTION="started"
                fi
            fi
        fi
    else
        CHECK_NAME="主路由"
        if ping -c 1 -W 1 -n -q "$CHECK_IP" >/dev/null 2>&1; then
            log "$CHECK_NAME $CHECK_IP 在线"
        else
            log "$CHECK_NAME $CHECK_IP 失联"
        fi
    fi

    rotate_log
    sleep "$CHECK_INTERVAL"
done