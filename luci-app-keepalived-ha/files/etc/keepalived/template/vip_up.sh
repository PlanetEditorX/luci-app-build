#!/bin/sh
VIP="@VIP@"
IFACE="@INTERFACE@"
logger -t "keepalived-ha-vip_up" "启动VIP绑定..."
sh /etc/keepalived/vip_manager.sh "$VIP" "$IFACE" bind
logger -t "keepalived-ha-vip_up" "VIP绑定完成"
