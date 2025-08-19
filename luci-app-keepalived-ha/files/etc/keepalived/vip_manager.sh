#!/bin/sh

# 参数定义
VIP="$1"           # 第一个参数：VIP地址
IFACE="$2"         # 第二个参数：绑定接口
ACTION="$3"        # 第三个参数：操作类型 bind/unbind/status
LOGTAG="keepalived-ha-vip_manager"

# 校验参数
[ -z "$VIP" ] || [ -z "$IFACE" ] || [ -z "$ACTION" ] && {
    echo "用法: vip_manager.sh <VIP> <INTERFACE> <bind|unbind|status>"
    exit 1
}

log() {
    logger -t "$LOGTAG" "$1"
}

case "$ACTION" in
    bind)
        if ip addr show dev "$IFACE" | grep -qw "$VIP"; then
            log "VIP $VIP 已存在于 $IFACE，跳过绑定"
        else
            ip addr add "$VIP"/24 dev "$IFACE" && \
            log "✅ VIP $VIP 已绑定到 $IFACE" || \
            log "❌ 绑定 VIP $VIP 到 $IFACE 失败"
        fi
        ;;
    unbind)
        if ip addr show dev "$IFACE" | grep -qw "$VIP"; then
            ip addr del "$VIP"/24 dev "$IFACE" && \
            log "✅ VIP $VIP 已从 $IFACE 解绑" || \
            log "❌ 解绑 VIP $VIP 从 $IFACE 失败"
        else
            log "VIP $VIP 不存在于 $IFACE，无需解绑"
        fi
        ;;
    status)
        if ip addr show dev "$IFACE" | grep -qw "$VIP"; then
            echo "✅ VIP $VIP 已绑定在 $IFACE"
            log "状态检查：VIP $VIP 已绑定在 $IFACE"
        else
            echo "❌ VIP $VIP 未绑定在 $IFACE"
            log "状态检查：VIP $VIP 未绑定在 $IFACE"
        fi
        ;;
    *)
        echo "未知操作: $ACTION"
        exit 1
        ;;
esac
