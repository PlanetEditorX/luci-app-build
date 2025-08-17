m = Map("keepalived_ha", "主路由高可用配置")

s = m:section(TypedSection, "main", "")
s.addremove = false
s.anonymous = true

s:option(Value, "vip", "虚拟 IP").default = "192.168.1.5"
s:option(Value, "interface", "绑定接口").default = "br-lan"
s:option(Value, "peer_ip", "旁路由 IP").default = "192.168.1.3"
s:option(Value, "priority", "优先级").default = "50"
s:option(Value, "fail_threshold", "故障阈值").default = "3"
s:option(Value, "recover_threshold", "恢复阈值").default = "2"
s:option(Value, "check_interval", "检测间隔").default = "5"
s:option(Flag, "enable", "启用").default = "0"

return m
