#!/bin/sh
VIP="@VIP@"
IFACE="@INTERFACE@"
sh /etc/keepalived/vip_manager.sh "$VIP" "$IFACE" bind
