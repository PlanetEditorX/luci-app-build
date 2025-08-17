module("luci.controller.keepalived_ha", package.seeall)

function index()
    entry({"admin", "services", "keepalived_ha"}, cbi("keepalived_ha"), "Keepalived HA", 90)
end
