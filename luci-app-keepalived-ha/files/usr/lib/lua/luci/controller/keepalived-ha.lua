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

    -- 日志页面
    entry({"admin", "services", "keepalived-ha", "logs"}, template("keepalived-ha/logs"), "运行日志", 4)
    entry({"admin", "services", "keepalived-ha", "clear_log"}, call("action_clear_log")).leaf = true
    entry({"admin", "services", "keepalived-ha", "get_logs"}, call("action_get_logs")).leaf = true

    -- 状态接口（供AJAX调用，始终启用）
    entry({"admin", "services", "keepalived-ha", "api_status"}, call("action_status")).leaf = true

    -- 服务控制接口
    entry({"admin", "services", "keepalived-ha", "control"}, call("action_control")).leaf = true
end

function action_status()
    local e = {}
    e.running = luci.sys.call("pgrep keepalived >/dev/null") == 0
    e.watchdog = luci.sys.call("pgrep failover_watchd >/dev/null") == 0

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

-- 新增日志处理函数
-- 保留与system_keepalived相关的处理（实际logread日志无需清理文件）
function action_clear_log()
    luci.http.prepare_content("text/plain")
    luci.http.write("系统日志无需手动清理（logread自动轮转）")
end


function action_get_logs()
    local log_type = luci.http.formvalue("type") or "system_keepalived"  -- 默认只处理系统日志
    local content = ""

    if log_type == "system_keepalived" then
        -- 核心修改：获取最近100行日志，并通过 tac 倒序输出（最新日志在顶部）
        -- 增加超时控制避免阻塞
        content = luci.sys.exec("logread | grep -i 'keepalived' | tail -n 100 2>/dev/null | awk '{a[i++]=$0} END {for (j=i-1; j>=0; j--) print a[j]}'")
    else
        content = "<%:未知日志类型%>"
    end

    luci.http.prepare_content("text/plain")
    luci.http.write(content)
end

-- 服务控制函数
function action_control()
    local action = luci.http.formvalue("action") or ""
    if action == "start" or action == "restart" then
        luci.sys.call("/etc/init.d/keepalived-ha restart >/dev/null 2>&1")
    elseif action == "stop" then
        luci.sys.call("/etc/init.d/keepalived-ha stop >/dev/null 2>&1")
    end
    luci.http.prepare_content("text/plain")
    luci.http.write("OK")
end