#!/bin/sh
logger -t keepalived "VIP @VIP@ 已绑定，从路由接管"
ip addr add @VIP@/24 dev @INTERFACE@