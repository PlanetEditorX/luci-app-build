-- 引入 SimpleSection 类
local SimpleSection = require "luci.cbi".SimpleSection

m = Map("keepalived-ha", translate("Keepalived 高可用"),
    translate("双路由虚拟IP（VIP）故障转移解决方案。请在下方配置主/备路由设置。"))

-- 基础设置段（使用 SimpleSection）
s = m:section(SimpleSection, "general", translate("基本设置"))
s.anonymous = true

-- 路由角色选择（核心：用这个选项控制其他选项的显示）
role = s:option(ListValue, "role", translate("路由角色"))
role:value("main", translate("主路由"))
role:value("peer", translate("备路由"))
role.default = "main"
role.rmempty = false

-- 公共配置
vip = s:option(Value, "vip", translate("虚拟IP（VIP）"))
vip.datatype = "ip4addr"
vip.default = "192.168.1.5"
vip.rmempty = false

interface = s:option(Value, "interface", translate("网络接口"))
interface.default = "br-lan"
for _, iface in ipairs(luci.sys.net.devices()) do
    interface:value(iface)
end
interface.rmempty = false

-- 主路由配置段（使用 SimpleSection，不直接调用 depends）
main = m:section(SimpleSection, "main", translate("主路由设置"),
    translate("仅当角色为'主路由'时生效"))
main.anonymous = true

-- 主路由选项通过 depends 关联到 role=main
peer_ip = main:option(Value, "peer_ip", translate("备路由IP"))
peer_ip.datatype = "ip4addr"
peer_ip.default = "192.168.1.3"
peer_ip.rmempty = false
peer_ip:depends("role", "main")  -- 关键：在选项上使用 depends

priority_main = main:option(Value, "priority", translate("VRRP优先级（低于备路由）"))
priority_main.datatype = "uinteger"
priority_main.default = "50"
priority_main.rmempty = false
priority_main:depends("role", "main")  -- 选项级别的依赖

fail_threshold = main:option(Value, "fail_threshold", translate("故障转移阈值"))
fail_threshold.datatype = "uinteger"
fail_threshold.default = "3"
fail_threshold.description = translate("触发故障转移所需的失败检查次数")
fail_threshold:depends("role", "main")

recover_threshold = main:option(Value, "recover_threshold", translate("恢复阈值"))
recover_threshold.datatype = "uinteger"
recover_threshold.default = "2"
recover_threshold:depends("role", "main")

check_interval = main:option(Value, "check_interval", translate("检查间隔（秒）"))
check_interval.datatype = "uinteger"
check_interval.default = "5"
check_interval:depends("role", "main")

-- 备路由配置段（使用 SimpleSection）
peer = m:section(SimpleSection, "peer", translate("备路由设置"),
    translate("仅当角色为'备路由'时生效"))
peer.anonymous = true

-- 备路由选项通过 depends 关联到 role=peer
main_ip = peer:option(Value, "main_ip", translate("主路由IP"))
main_ip.datatype = "ip4addr"
main_ip.default = "192.168.1.2"
main_ip.rmempty = false
main_ip:depends("role", "peer")  -- 选项级别的依赖

priority_peer = peer:option(Value, "priority", translate("VRRP优先级（高于主路由）"))
priority_peer.datatype = "uinteger"
priority_peer.default = "100"
priority_peer.rmempty = false
priority_peer:depends("role", "peer")

return m