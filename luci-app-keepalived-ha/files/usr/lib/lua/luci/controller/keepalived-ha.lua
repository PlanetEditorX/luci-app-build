module("luci.controller.keepalived-ha", package.seeall)

function index()
    -- 主菜单入口
    local page = entry({"admin", "services", "keepalived-ha"}, firstchild(), "Keepalived HA", 60)
    page.dependent = false  -- 确保主菜单始终可见

    -- 读取当前路由角色（从UCI配置中获取）
    local uci = require "luci.model.uci".cursor()
    local role = uci:get("keepalived-ha", "general", "role") or "main"  -- 默认主路由

    -- 基本设置页面（包含状态信息）
    entry({"admin", "services", "keepalived-ha", "basic"}, cbi("keepalived-ha/basic"), "基本设置", 1)

    -- 主路由设置页面（仅角色为main时显示）
    if role == "main" then
        entry({"admin", "services", "keepalived-ha", "main"}, cbi("keepalived-ha/main"), "主路由设置", 2)
    end

    -- 从路由设置页面（仅角色为peer时显示）
    if role == "peer" then
        entry({"admin", "services", "keepalived-ha", "peer"}, cbi("keepalived-ha/peer"), "从路由设置", 3)
    end

    -- 状态接口（供AJAX调用，始终启用）
    entry({"admin", "services", "keepalived-ha", "api_status"}, call("action_status")).leaf = true
end

function action_status()
    local e = {}
    e.running = luci.sys.call("pgrep keepalived >/dev/null") == 0
    e.watchdog = luci.sys.call("pgrep failover_watchdog.sh >/dev/null") == 0

    -- 添加VIP状态检查
    local uci = require "luci.model.uci".cursor()
    e.vip = uci:get("keepalived-ha", "general", "vip") or ""
    e.interface = uci:get("keepalived-ha", "general", "interface") or "br-lan"

    if e.vip ~= "" then
        e.vip_bound = luci.sys.call("ip addr show dev %s | grep -q %s" % {e.interface, e.vip}) == 0
    else
        e.vip_bound = false
    end

    luci.http.prepare_content("application/json")
    luci.http.write_json(e)
end