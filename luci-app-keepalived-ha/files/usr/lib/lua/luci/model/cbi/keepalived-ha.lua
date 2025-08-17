m = Map("keepalived-ha", translate("Keepalived High Availability"),
    translate("Dual-router VIP failover solution. Configure main/peer router settings below."))

-- 使用 SimpleSection 替代抽象 Section 类，解决继承错误
s = m:section(SimpleSection, "general", translate("Basic Settings"))
s.anonymous = true  -- 匿名节（不显示节名称）

-- 路由角色选择
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

-- 主路由配置（使用 SimpleSection 避免抽象类错误）
main = m:section(SimpleSection, "main", translate("Main Router Settings"),
    translate("Only effective when role is 'Main Router'"))
main.anonymous = true
main:depends("role", "main")  -- 基于角色显示/隐藏

peer_ip = main:option(Value, "peer_ip", translate("Peer Router IP"))
peer_ip.datatype = "ip4addr"
peer_ip.default = "192.168.1.3"
peer_ip.rmempty = false

priority_main = main:option(Value, "priority", translate("VRRP Priority (lower than peer)"))
priority_main.datatype = "uinteger"
priority_main.default = "50"
priority_main.rmempty = false

-- 添加主路由优先级校验（必须低于旁路由默认值）
priority_main.validate = function(self, value)
    local val = tonumber(value)
    if not val then
        return nil, translate("Please enter a valid number")
    end
    if val >= 100 then  -- 旁路由默认优先级为100
        return nil, translate("Main router priority must be lower than 100")
    end
    return value
end

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
check_interval:value(1)
check_interval:value(3)
check_interval:value(5)
check_interval:value(10)

-- 旁路由配置（使用 SimpleSection 避免抽象类错误）
peer = m:section(SimpleSection, "peer", translate("Peer Router Settings"),
    translate("Only effective when role is 'Peer Router'"))
peer.anonymous = true
peer:depends("role", "peer")  -- 基于角色显示/隐藏

main_ip = peer:option(Value, "main_ip", translate("Main Router IP"))
main_ip.datatype = "ip4addr"
main_ip.default = "192.168.1.2"
main_ip.rmempty = false

priority_peer = peer:option(Value, "priority", translate("VRRP Priority (higher than main)"))
priority_peer.datatype = "uinteger"
priority_peer.default = "100"
priority_peer.rmempty = false

-- 添加旁路由优先级校验（必须高于主路由默认值）
priority_peer.validate = function(self, value)
    local val = tonumber(value)
    if not val then
        return nil, translate("Please enter a valid number")
    end
    if val <= 50 then  -- 主路由默认优先级为50
        return nil, translate("Peer router priority must be higher than 50")
    end
    return value
end

return m