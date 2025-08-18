-- 引入所需模块
local NamedSection = require("luci.cbi").NamedSection
local TypedSection = require("luci.cbi").TypedSection
local SimpleSection = require("luci.cbi").SimpleSection
local uci = require("luci.model.uci").cursor()
local util = require("luci.util")

m = Map("keepalived-ha",
    translate("Keepalived 高可用"),
    translate("双路由虚拟IP（VIP）故障转移解决方案，支持主备路由自动切换。配置前请确保主备路由网络互通。")
)

-- ########## 1. 嵌入JavaScript（无模板依赖）##########
local js_sec = m:section(SimpleSection)
function js_sec:render()
    return [[
    <script>
        // 角色切换确认+自动保存
        function confirmRoleChange(sel) {
            const newRole = sel.options[sel.selectedIndex].text;
            if (confirm('确定切换为【' + newRole + '】吗？切换后自动保存！')) {
                document.querySelector('form').submit();
                return true;
            } else {
                sel.value = sel.dataset.orig;
                return false;
            }
        }
        // 记录初始值
        window.onload = function() {
            const roleSel = document.getElementById('role-select');
            if (roleSel) roleSel.dataset.orig = roleSel.value;
        };
    </script>
    ]]
end

-- ########## 2. 基础设置段（父section）##########
local general_sec = m:section(NamedSection, "general", "general", translate("基本设置"))
general_sec.anonymous = false

-- ########## 3. 路由角色选择（核心修复：替换self:name()）##########
local role = general_sec:option(ListValue, "role", translate("路由角色"))
role:value("main", translate("主路由"))
role:value("peer", translate("备路由"))
role.default = "main"
role.rmempty = false
role.description = translate("主路由正常情况下持有VIP，备路由在主路由故障时接管")

function role:render()
    -- 核心修复：用self.option获取字段名（替代self:name()）
    local input_name = self.option  -- LuCI控件的字段名存储在self.option中
    local fixed_id = "role-select"
    -- 核心修复：用self.map:get获取当前值（替代self:cfgvalue()，避免上下文依赖）
    local current_val = self.map:get("general", "role") or self.default or "main"

    -- 生成下拉框HTML
    local html = string.format(
        '<select name="%s" id="%s" class="cbi-input-select" onchange="return confirmRoleChange(this)">',
        util.htmlescape(input_name), fixed_id
    )

    -- 添加选项
    for _, opt in ipairs(self.options) do
        local val = opt[1]
        local txt = opt[2]
        local selected = (val == current_val) and ' selected="selected"' or ""
        html = html .. string.format(
            '<option value="%s"%s>%s</option>',
            util.htmlescape(val), selected, util.htmlescape(txt)
        )
    end

    -- 添加描述
    html = html .. '</select>'
    if self.description then
        html = html .. string.format(
            '<br /><span class="cbi-section-descr">%s</span>',
            util.htmlescape(self.description)
        )
    end

    return html
end

-- ########## 4. 公共配置（无修改，仅确保父section正确）##########
local vip_option = general_sec:option(Value, "vip", translate("虚拟IP（VIP）"))
vip_option.datatype = "ip4addr"
vip_option.default = "192.168.1.5"
vip_option.description = translate("用于客户端访问的虚拟IP地址，需与路由在同一网段")

local interface_option = general_sec:option(Value, "interface", translate("绑定网络接口"))
interface_option.default = "br-lan"
interface_option.description = translate("绑定VIP的网络接口，通常为LAN接口")

-- 动态添加网络接口
for _, iface in ipairs(luci.sys.net.devices()) do
    if iface ~= "lo" and not iface:match("^tun") and not iface:match("^tap") then
        interface_option:value(iface)
    end
end

-- 健康检查方式
local check_method = general_sec:option(ListValue, "check_method", translate("健康检查方式"))
check_method:value("ping", translate("ICMP Ping"))
check_method:value("tcp", translate("TCP 端口"))
check_method:value("http", translate("HTTP 请求"))
check_method.default = "ping"

-- TCP端口
local tcp_port = general_sec:option(Value, "tcp_port", translate("TCP 检查端口"))
tcp_port.datatype = "port"
tcp_port.default = "80"
tcp_port:depends("check_method", "tcp")

-- HTTP URL
local http_url = general_sec:option(Value, "http_url", translate("HTTP 检查URL"))
http_url.default = "http://192.168.1.1/"
http_url:depends("check_method", "http")

-- VRID
local vrid_option = general_sec:option(Value, "vrid", translate("VRID 标识"),
    translate("虚拟路由ID，主备路由必须一致，范围1-255"))
vrid_option.datatype = "range(1,255)"
vrid_option.default = "51"

-- 高级选项
local advanced = general_sec:option(Flag, "advanced_mode", translate("显示高级选项"),
    translate("开启后可配置更多高级参数"))
advanced.default = 0

-- 抢占模式
local preempt = general_sec:option(ListValue, "preempt", translate("抢占模式"),
    translate("主路由恢复后是否抢占VIP"))
preempt:value("true", translate("允许抢占"))
preempt:value("false", translate("不允许抢占"))
preempt.default = "true"
preempt:depends("advanced_mode", "1")

-- OpenClash控制
local control_openclash = general_sec:option(Flag, "control_openclash", translate("自动控制OpenClash"),
    translate("故障转移时自动启停OpenClash"))
control_openclash.default = "1"

-- ########## 5. 角色对应的配置段（无修改）##########
local role_value = uci:get("keepalived-ha", "general", "role") or "main"
if role_value == "main" then
    local main_section = m:section(TypedSection, "main", translate("主路由设置"))
    main_section.anonymous = true
    main_section.addremove = false
    main_section.description = translate("仅当角色为'主路由'时生效的配置参数")

    local peer_ip = main_section:option(Value, "peer_ip", translate("备路由IP地址"))
    peer_ip.datatype = "ip4addr"
    peer_ip.default = "192.168.1.3"
    peer_ip.description = translate("备路由的实际IP地址，用于健康监测")

    local priority = main_section:option(Value, "priority", translate("VRRP优先级"),
        translate("主路由优先级应低于备路由（建议50-90）"))
    priority.datatype = "uinteger"
    priority.default = "50"

    local fail_th = main_section:option(Value, "fail_threshold", translate("故障转移阈值"))
    fail_th.datatype = "range(1,10)"
    fail_th.default = "3"
    fail_th.description = translate("连续检测失败次数，达到此值触发转移（1-10）")

    local recover_th = main_section:option(Value, "recover_threshold", translate("恢复阈值"))
    recover_th.datatype = "range(1,10)"
    recover_th.default = "2"
    recover_th.description = translate("连续检测成功次数，达到此值恢复（1-10）")

    local check_int = main_section:option(Value, "check_interval", translate("检查间隔（秒）"))
    check_int.datatype = "range(2,60)"
    check_int.default = "5"
    check_int.description = translate("健康检查的时间间隔（2-60秒）")
end

if role_value == "peer" then
    local peer_section = m:section(TypedSection, "peer", translate("备路由设置"))
    peer_section.anonymous = true
    peer_section.addremove = false
    peer_section.description = translate("仅当角色为'备路由'时生效的配置参数")

    local main_ip = peer_section:option(Value, "main_ip", translate("主路由IP地址"))
    main_ip.datatype = "ip4addr"
    main_ip.default = "192.168.1.2"
    main_ip.description = translate("主路由的实际IP地址，用于健康监测")

    local priority = peer_section:option(Value, "priority", translate("VRRP优先级"),
        translate("备路由优先级应高于主路由（建议100-150）"))
    priority.datatype = "uinteger"
    priority.default = "100"
end

-- ########## 6. 提交后重启服务##########
function m.on_after_commit(self)
    luci.sys.call("/etc/init.d/keepalived-ha restart >/dev/null 2>&1")
    luci.util.perror(translate("配置已保存，服务已自动重启"))
end

return m