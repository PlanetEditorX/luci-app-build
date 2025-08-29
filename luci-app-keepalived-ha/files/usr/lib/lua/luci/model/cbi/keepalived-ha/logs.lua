module("luci.model.cbi.keepalived-ha.logs", package.seeall)

function index()
    -- 仅保留系统日志，倒序输出
    local system_keepalived_log = luci.sys.exec("logread | grep -i 'keepalived' | tail -n 100 2>/dev/null | awk '{a[i++]=$0} END {for (j=i-1; j>=0; j--) print a[j]}'")
    system_keepalived_log = system_keepalived_log ~= "" and system_keepalived_log or "未找到系统Keepalived日志"

    luci.template.render("keepalived-ha/logs", {
        system_keepalived_log = system_keepalived_log
    })
end