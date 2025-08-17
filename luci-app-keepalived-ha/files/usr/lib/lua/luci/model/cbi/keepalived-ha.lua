-- 引入 SimpleSection 类
local SimpleSection = require "luci.cbi".SimpleSection

m = Map("keepalived-ha", translate("Keepalived High Availability"),
    translate("Dual-router VIP failover solution. Configure main/peer router settings below."))

-- 基础设置段（使用 SimpleSection）
s = m:section(SimpleSection, "general", translate("Basic Settings"))
s.anonymous = true

-- 路由角色选择（核心：用这个选项控制其他选项的显示）
role = s:option(ListValue, "role", translate("Router Role"))
role:value("main", translate("Main Router"))
role:value("peer", translate("Peer Router"))
role.default = "main"
role.rmempty = false

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

-- 主路由配置段（使用 SimpleSection，不直接调用 depends）
main = m:section(SimpleSection, "main", translate("Main Router Settings"),
    translate("Only effective when role is 'Main Router'"))
main.anonymous = true

-- 主路由选项通过 depends 关联到 role=main
peer_ip = main:option(Value, "peer_ip", translate("Peer Router IP"))
peer_ip.datatype = "ip4addr"
peer_ip.default = "192.168.1.3"
peer_ip.rmempty = false
peer_ip:depends("role", "main")  -- 关键：在选项上使用 depends

priority_main = main:option(Value, "priority", translate("VRRP Priority (lower than peer)"))
priority_main.datatype = "uinteger"
priority_main.default = "50"
priority_main.rmempty = false
priority_main:depends("role", "main")  -- 选项级别的依赖

fail_threshold = main:option(Value, "fail_threshold", translate("Failover Threshold"))
fail_threshold.datatype = "uinteger"
fail_threshold.default = "3"
fail_threshold.description = translate("Number of failed checks to trigger failover")
fail_threshold:depends("role", "main")

recover_threshold = main:option(Value, "recover_threshold", translate("Recovery Threshold"))
recover_threshold.datatype = "uinteger"
recover_threshold.default = "2"
recover_threshold:depends("role", "main")

check_interval = main:option(Value, "check_interval", translate("Check Interval (seconds)"))
check_interval.datatype = "uinteger"
check_interval.default = "5"
check_interval:depends("role", "main")

-- 旁路由配置段（使用 SimpleSection）
peer = m:section(SimpleSection, "peer", translate("Peer Router Settings"),
    translate("Only effective when role is 'Peer Router'"))
peer.anonymous = true

-- 旁路由选项通过 depends 关联到 role=peer
main_ip = peer:option(Value, "main_ip", translate("Main Router IP"))
main_ip.datatype = "ip4addr"
main_ip.default = "192.168.1.2"
main_ip.rmempty = false
main_ip:depends("role", "peer")  -- 选项级别的依赖

priority_peer = peer:option(Value, "priority", translate("VRRP Priority (higher than main)"))
priority_peer.datatype = "uinteger"
priority_peer.default = "100"
priority_peer.rmempty = false
priority_peer:depends("role", "peer")

return m