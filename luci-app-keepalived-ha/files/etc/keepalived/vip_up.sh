#!/bin/sh
logger -t keepalived "VIP @VIP@ 已绑定，旁路由接管"
ip addr add @VIP@/24 dev @INTERFACE@