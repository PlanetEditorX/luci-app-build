m = Map("keepalived-ha",
    translate("Keepalived 高可用"),
    translate("双路由虚拟IP（VIP）故障转移解决方案，支持主备路由自动切换。配置前请确保主备路由网络互通。")
)

-- 基础设置段（使用 NamedSection 而非 SimpleSection，确保继承自 AbstractSection）
s = m:section(NamedSection, "general", "general", translate("基本设置"))
s.anonymous = true

-- 路由角色选择
role = s:option(ListValue, "role", translate("路由角色"))
role:value("main", translate("主路由"))
role:value("peer", translate("备路由"))
role.default = "main"
role.rmempty = false
role.description = translate("主路由正常情况下持有VIP，备路由在主路由故障时接管")

-- 公共配置
vip = s:option(Value, "vip", translate("虚拟IP（VIP）"))
vip.datatype = "ip4addr"
vip.default = "192.168.1.5"
vip.rmempty = false
vip.description = translate("用于客户端访问的虚拟IP地址，需与路由在同一网段")

interface = s:option(Value, "interface", translate("绑定网络接口"))
interface.default = "br-lan"
-- 过滤掉不适合的网络接口
for _, iface in ipairs(luci.sys.net.devices()) do
    -- 排除回环和隧道接口
    if iface ~= "lo" and not iface:match("^tun") and not iface:match("^tap") then
        interface:value(iface)
    end
end
interface.rmempty = false
interface.description = translate("绑定VIP的网络接口，通常为LAN接口")

-- 健康检查方式
check_method = s:option(ListValue, "check_method", translate("健康检查方式"))
check_method:value("ping", translate("ICMP Ping"))
check_method:value("tcp", translate("TCP 端口"))
check_method:value("http", translate("HTTP 请求"))
check_method.default = "ping"
check_method.rmempty = false

-- TCP检查端口（依赖检查方式）
tcp_port = s:option(Value, "tcp_port", translate("TCP 检查端口"))
tcp_port.datatype = "port"
tcp_port.default = "80"
tcp_port:depends("check_method", "tcp")

-- HTTP检查URL（依赖检查方式）
http_url = s:option(Value, "http_url", translate("HTTP 检查URL"))
http_url.default = "http://192.168.1.1/"
http_url:depends("check_method", "http")

-- VRID配置（虚拟路由标识）
vrid = s:option(Value, "vrid", translate("VRID 标识"),
    translate("虚拟路由ID，主备路由必须一致，范围1-255"))
vrid.datatype = "range(1,255)"
vrid.default = "51"
vrid.rmempty = false

-- 主路由配置段
main = m:section(NamedSection, "main", "main", translate("主路由设置"),
    translate("仅当角色为'主路由'时生效的配置参数"))
main:depends("role", "main")
main.anonymous = true

peer_ip = main:option(Value, "peer_ip", translate("备路由IP地址"))
peer_ip.datatype = "ip4addr"
peer_ip.default = "192.168.1.3"
peer_ip.rmempty = false
peer_ip.description = translate("备路由的实际IP地址，用于健康监测")

priority_main = main:option(Value, "priority", translate("VRRP优先级"),
    translate("主路由优先级应低于备路由（建议50-90）"))
priority_main.datatype = "uinteger"
priority_main.default = "50"
priority_main.rmempty = false

fail_threshold = main:option(Value, "fail_threshold", translate("故障转移阈值"))
fail_threshold.datatype = "range(1,10)"
fail_threshold.default = "3"
fail_threshold.description = translate("连续检测失败次数，达到此值触发转移（1-10）")

recover_threshold = main:option(Value, "recover_threshold", translate("恢复阈值"))
recover_threshold.datatype = "range(1,10)"
recover_threshold.default = "2"
recover_threshold.description = translate("连续检测成功次数，达到此值恢复（1-10）")

check_interval = main:option(Value, "check_interval", translate("检查间隔（秒）"))
check_interval.datatype = "range(2,60)"
check_interval.default = "5"
check_interval.description = translate("健康检查的时间间隔（2-60秒）")

-- 备路由配置段
peer = m:section(NamedSection, "peer", "peer", translate("备路由设置"),
    translate("仅当角色为'备路由'时生效的配置参数"))
peer:depends("role", "peer")
peer.anonymous = true

main_ip = peer:option(Value, "main_ip", translate("主路由IP地址"))
main_ip.datatype = "ip4addr"
main_ip.default = "192.168.1.2"
main_ip.rmempty = false
main_ip.description = translate("主路由的实际IP地址，用于健康监测")

priority_peer = peer:option(Value, "priority", translate("VRRP优先级"),
    translate("备路由优先级应高于主路由（建议100-150）"))
priority_peer.datatype = "uinteger"
priority_peer.default = "100"
priority_peer.rmempty = false

-- 高级选项开关
advanced = s:option(Flag, "advanced_mode", translate("显示高级选项"),
    translate("开启后可配置更多高级参数"))
advanced.default = 0

-- 抢占模式设置（高级选项）
preempt = s:option(ListValue, "preempt", translate("抢占模式"),
    translate("主路由恢复后是否抢占VIP"))
preempt:value("true", translate("允许抢占"))
preempt:value("false", translate("不允许抢占"))
preempt.default = "true"
preempt:depends("advanced_mode", "1")

-- OpenClash控制开关
control_openclash = s:option(Flag, "control_openclash", translate("自动控制OpenClash"),
    translate("故障转移时自动启停OpenClash"))
control_openclash.default = "1"
control_openclash.rmempty = false

-- 配置提交后的操作提示
function m.on_after_commit(self)
    luci.sys.call("/etc/init.d/keepalived-ha restart >/dev/null 2>&1")
    luci.util.perror(translate("配置已保存，服务已自动重启"))
end

return m