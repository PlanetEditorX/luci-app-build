-- 引入必要的 CBI 类（SimpleSection 是 AbstractSection 的具体子类）
local SimpleSection = require "luci.cbi".SimpleSection

m = Map("keepalived-ha",
    translate("Keepalived High Availability"),
    translate("Dual-router VIP failover solution. Configure main/peer router settings below.")
)

-- 基础设置段（使用 SimpleSection 替代抽象 Section 类）
s = m:section(SimpleSection, "general", translate("Basic Settings"))
s.anonymous = true  -- 匿名节（不显示节名称）

-- 路由角色选择
role = s:option(ListValue, "role", translate("Router Role"))
role:value("main", translate("Main Router"))
role:value("peer", translate("Peer Router"))
role.default = "main"
role.rmempty = false

-- 公共配置：虚拟 IP
vip = s:option(Value, "vip", translate("Virtual IP (VIP)"))
vip.datatype = "ip4addr"
vip.default = "192.168.1.5"
vip.rmempty = false

-- 公共配置：网络接口
interface = s:option(Value, "interface", translate("Network Interface"))
interface.default = "br-lan"
-- 自动填充系统可用接口
for _, iface in ipairs(luci.sys.net.devices()) do
    interface:value(iface)
end
interface.rmempty = false

-- 主路由配置段（使用 SimpleSection）
main = m:section(SimpleSection, "main",
    translate("Main Router Settings"),
    translate("Only effective when role is 'Main Router'")
)
main.anonymous = true
main:depends("role", "main")  -- 仅当角色为主路由时显示

-- 主路由配置：旁路由 IP
peer_ip = main:option(Value, "peer_ip", translate("Peer Router IP"))
peer_ip.datatype = "ip4addr"
peer_ip.default = "192.168.1.3"
peer_ip.rmempty = false

-- 主路由配置：VRRP 优先级
priority_main = main:option(Value, "priority", translate("VRRP Priority (lower than peer)"))
priority_main.datatype = "uinteger"
priority_main.default = "50"
priority_main.rmempty = false

-- 主路由配置：故障转移阈值
fail_threshold = main:option(Value, "fail_threshold", translate("Failover Threshold"))
fail_threshold.datatype = "uinteger"
fail_threshold.default = "3"
fail_threshold.description = translate("Number of failed checks to trigger failover")

-- 主路由配置：恢复阈值
recover_threshold = main:option(Value, "recover_threshold", translate("Recovery Threshold"))
recover_threshold.datatype = "uinteger"
recover_threshold.default = "2"

-- 主路由配置：检查间隔
check_interval = main:option(Value, "check_interval", translate("Check Interval (seconds)"))
check_interval.datatype = "uinteger"
check_interval.default = "5"

-- 旁路由配置段（使用 SimpleSection）
peer = m:section(SimpleSection, "peer",
    translate("Peer Router Settings"),
    translate("Only effective when role is 'Peer Router'")
)
peer.anonymous = true
peer:depends("role", "peer")  -- 仅当角色为旁路由时显示

-- 旁路由配置：主路由 IP
main_ip = peer:option(Value, "main_ip", translate("Main Router IP"))
main_ip.datatype = "ip4addr"
main_ip.default = "192.168.1.2"
main_ip.rmempty = false

-- 旁路由配置：VRRP 优先级
priority_peer = peer:option(Value, "priority", translate("VRRP Priority (higher than main)"))
priority_peer.datatype = "uinteger"
priority_peer.default = "100"
priority_peer.rmempty = false

return m