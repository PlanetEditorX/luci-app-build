m = Map("keepalived-ha")

-- 主路由配置段
local main_section = m:section(NamedSection, "main", "main", translate("配置参数"))
main_section.anonymous = false

local peer_ip_option = main_section:option(Value, "peer_ip", translate("从路由IP地址"))
peer_ip_option.datatype = "ip4addr"
peer_ip_option.default = "192.168.1.3"
peer_ip_option.description = translate("从路由的实际IP地址，用于健康监测")

local priority_main_option = main_section:option(Value, "priority", translate("VRRP优先级"),
	translate("主路由优先级应低于从路由（建议50-90）"))
priority_main_option.datatype = "uinteger"
priority_main_option.default = "50"

local fail_threshold_option = main_section:option(Value, "fail_threshold", translate("故障转移阈值"))
fail_threshold_option.datatype = "range(1,10)"
fail_threshold_option.default = "3"
fail_threshold_option.description = translate("连续检测失败次数，达到此值触发转移（1-10）")

local recover_threshold_option = main_section:option(Value, "recover_threshold", translate("恢复阈值"))
recover_threshold_option.datatype = "range(1,10)"
recover_threshold_option.default = "5"
recover_threshold_option.description = translate("连续检测成功次数，达到此值恢复（1-10）")

local check_interval_option = main_section:option(Value, "check_interval", translate("检查间隔（秒）"))
check_interval_option.datatype = "range(2,60)"
check_interval_option.default = "5"
check_interval_option.description = translate("健康检查的时间间隔（2-60秒）")

-- OpenClash控制开关
local control_openclash = main_section:option(Flag, "control_openclash", translate("自动控制OpenClash"),
    translate("故障转移时自动启停OpenClash"))
control_openclash.default = "1"

function m.on_after_commit(self)
    luci.sys.call("/etc/init.d/keepalived-ha restart >/dev/null 2>&1")
    luci.util.perror(translate("配置已保存，服务已重启"))
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "keepalived-ha", "basic"))
end

return m