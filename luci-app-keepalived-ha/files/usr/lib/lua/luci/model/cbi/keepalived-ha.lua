m = Map("keepalived-ha", translate("Keepalived High Availability"),
    translate("Dual-router VIP failover solution. Configure main/peer router settings below."))

s = m:section(NamedSection, "general", "general", translate("Basic Settings"))

-- 路由角色选择
role = s:option(ListValue, "role", translate("Router Role"))
role:value("main", translate("Main Router"))
role:value("peer", translate("Peer Router"))
role.default = "main"

-- 公共配置
vip = s:option(Value, "vip", translate("Virtual IP (VIP)"))
vip.datatype = "ip4addr"
vip.default = "192.168.1.5"
vip.rmempty = false

interface = s:option(Value, "interface", translate("Network Interface"))
interface.default = "br-lan"
for _, iface in ipairs(luci.sys.net.devices()) do
    interface:value(iface)
end
interface.rmempty = false

-- 主路由配置
main = m:section(NamedSection, "main", "main", translate("Main Router Settings"),
    translate("Only effective when role is 'Main Router'"))
main:depends("role", "main")

peer_ip = main:option(Value, "peer_ip", translate("Peer Router IP"))
peer_ip.datatype = "ip4addr"
peer_ip.default = "192.168.1.3"
peer_ip.rmempty = false

priority_main = main:option(Value, "priority", translate("VRRP Priority (lower than peer)"))
priority_main.datatype = "uinteger"
priority_main.default = "50"
priority_main.rmempty = false

fail_threshold = main:option(Value, "fail_threshold", translate("Failover Threshold"))
fail_threshold.datatype = "uinteger"
fail_threshold.default = "3"
fail_threshold.description = translate("Number of failed checks to trigger failover")

recover_threshold = main:option(Value, "recover_threshold", translate("Recovery Threshold"))
recover_threshold.datatype = "uinteger"
recover_threshold.default = "2"

check_interval = main:option(Value, "check_interval", translate("Check Interval (seconds)"))
check_interval.datatype = "uinteger"
check_interval.default = "5"

-- 旁路由配置
peer = m:section(NamedSection, "peer", "peer", translate("Peer Router Settings"),
    translate("Only effective when role is 'Peer Router'"))
peer:depends("role", "peer")

main_ip = peer:option(Value, "main_ip", translate("Main Router IP"))
main_ip.datatype = "ip4addr"
main_ip.default = "192.168.1.2"
main_ip.rmempty = false

priority_peer = peer:option(Value, "priority", translate("VRRP Priority (higher than main)"))
priority_peer.datatype = "uinteger"
priority_peer.default = "100"
priority_peer.rmempty = false

return m