module("luci.controller.keepalived-ha", package.seeall)

function index()
    entry({"admin", "services", "keepalived-ha"}, cbi("keepalived-ha"), "Keepalived HA", 60)
    entry({"admin", "services", "keepalived-ha", "status"}, call("action_status")).leaf = true
end

function action_status()
    local e = {}
    e.running = luci.sys.call("pgrep keepalived >/dev/null") == 0
    e.watchdog = luci.sys.call("pgrep failover_watchdog.sh >/dev/null") == 0
    luci.http.prepare_content("application/json")
    luci.http.write_json(e)
end
