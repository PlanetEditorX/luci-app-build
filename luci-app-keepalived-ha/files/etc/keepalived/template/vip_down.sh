#!/bin/sh
VIP="@VIP@"
IFACE="@INTERFACE@"
logger -t "keepalived-ha [vip_down]" "启动VIP解绑..."
sh /etc/keepalived/vip_manager.sh "$VIP" "$IFACE" unbind
logger -t "keepalived-ha [vip_down]" "VIP解绑完成"
