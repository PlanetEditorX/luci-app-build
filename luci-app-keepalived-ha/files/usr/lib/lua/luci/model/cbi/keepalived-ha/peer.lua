m = Map("keepalived-ha")

-- 从路由配置段
local peer_section = m:section(NamedSection, "peer", "peer", translate("配置参数"))
peer_section.anonymous = false

local main_ip_option = peer_section:option(Value, "main_ip", translate("主路由IP地址"))
main_ip_option.datatype = "ip4addr"
main_ip_option.default = "192.168.1.2"
main_ip_option.description = translate("主路由的实际IP地址，用于健康监测")

local priority_peer_option = peer_section:option(Value, "priority", translate("VRRP优先级"),
	translate("从路由优先级应高于主路由（建议100-150）"))
priority_peer_option.datatype = "uinteger"
priority_peer_option.default = "100"

local check_interval_option = peer_section:option(Value, "check_interval", translate("检查间隔（秒）"))
check_interval_option.datatype = "range(2,60)"
check_interval_option.default = "5"
check_interval_option.description = translate("健康检查的时间间隔（2-60秒）")

function m.on_after_commit(self)
	luci.model.uci.cursor():commit("keepalived-ha")
    luci.sys.call("/etc/init.d/keepalived-ha restart >/dev/null 2>&1")
    luci.util.perror(translate("配置已保存，服务已重启"))
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "keepalived-ha", "basic"))
end

return m