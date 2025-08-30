-- 引入必要模块（补充翻译函数）
local translate = require("luci.i18n").translate
-- local m = Map("keepalived-ha", translate("基本设置"), translate("全局通用配置参数，主从路由VIP和VRID需保持一致"))
local m = Map("keepalived-ha", translate("基本设置"),
    translate("Keepalived高可用配置，实现主从路由VIP漂移和故障转移"))

-- 状态显示作为一个独立节，继承 LuCI 样式
local status = m:section(TypedSection, "_status", translate("系统状态"))
status.template = "keepalived-ha/status_inline"
status.anonymous = true
status.description = translate("显示Keepalived服务状态、VIP绑定情况等")
-- 让 _status 节不参与 UCI 提交流程
status.cfgsections = function() return {} end


-- 绑定配置文件中的 "general" 节
local s = m:section(NamedSection, "general", "general", translate("基础参数"))
s.anonymous = false  -- 非匿名节，与配置文件对应

-- 路由角色选择（补充描述）
local role = s:option(ListValue, "role", translate("路由角色"))
role:value("main", translate("主路由"))
role:value("peer", translate("从路由"))
role.default = "main"
role.description = translate(
    "主路由：从路由故障时接管VIP<br>" ..
    "从路由：正常情况下持有VIP<br>" ..
    "切换角色并应用后，先重启再修改后续设置"
)

-- VIP设置（补充默认值和描述）
local vip = s:option(Value, "vip", translate("虚拟IP（VIP）"))
vip.datatype = "ip4addr"
vip.default = "192.168.1.5"  -- 添加默认值
vip.description = translate("客户端访问的虚拟IP，需与路由同网段")

-- 网络接口（过滤无效接口）
local iface = s:option(Value, "interface", translate("绑定网络接口"))
iface.default = "br-lan"  -- 添加默认值
iface.description = translate("绑定VIP的接口，通常为LAN接口")

-- 动态加载接口（排除回环和虚拟接口）
for _, i in ipairs(luci.sys.net.devices()) do
    if i ~= "lo" and not i:match("^tun") and not i:match("^tap") then
        iface:value(i)
    end
end

-- VRID配置（虚拟路由标识）
local vrid_option = s:option(Value, "vrid", translate("VRID 标识"),
    translate("虚拟路由ID，主从路由必须一致，范围1-255"))
vrid_option.datatype = "range(1,255)"
vrid_option.default = "51"

-- 提交后操作
function m.on_after_commit(self)
    -- 强制保存UCI配置
    luci.model.uci.cursor():commit("keepalived-ha")
    -- 重启服务
    luci.sys.call("/etc/init.d/keepalived-ha restart >/dev/null 2>&1")
    -- 延迟跳转，确保配置生效
    luci.http.redirect(luci.dispatcher.build_url("admin", "services", "keepalived-ha", "basic"))
    luci.util.perror(translate("配置已保存，服务已重启"))
end

return m