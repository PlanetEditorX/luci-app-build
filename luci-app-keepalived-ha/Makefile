include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-keepalived-ha
PKG_VERSION:=1.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/luci/luci.mk

# 定义包信息
define Package/$(PKG_NAME)
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=9. Services
	TITLE:=Keepalived High Availability
	DEPENDS:=+keepalived +nftables +ip-full +procps-ng-pkill
	PKGARCH:=all
endef

# 包描述
define Package/$(PKG_NAME)/description
	Dual-router VIP failover solution with Keepalived.
	Provides high availability through automatic VIP (Virtual IP) failover
	between main and peer routers, with health check monitoring.
endef

# 安装文件（注意：以下每行命令必须以Tab键开头，而非空格）
define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/keepalived-ha $(1)/etc/config/keepalived-ha

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/failover_watchdog $(1)/etc/init.d/failover_watchdog
	$(INSTALL_BIN) ./files/etc/init.d/keepalived-ha $(1)/etc/init.d/keepalived-ha

	$(INSTALL_DIR) $(1)/etc/keepalived
	$(INSTALL_BIN) ./files/etc/keepalived/keepalived-ha-debug.sh $(1)/etc/keepalived/
	$(INSTALL_BIN) ./files/etc/keepalived/vip_manager.sh $(1)/etc/keepalived/

	$(INSTALL_DIR) $(1)/etc/keepalived/template
	$(INSTALL_DATA) ./files/etc/keepalived/template/keepalived_main.conf $(1)/etc/keepalived/template/
	$(INSTALL_DATA) ./files/etc/keepalived/template/keepalived_peer.conf $(1)/etc/keepalived/template/
	$(INSTALL_BIN) ./files/etc/keepalived/template/failover_watchdog.sh $(1)/etc/keepalived/template/
	$(INSTALL_BIN) ./files/etc/keepalived/template/vip_up.sh $(1)/etc/keepalived/template/
	$(INSTALL_BIN) ./files/etc/keepalived/template/vip_down.sh $(1)/etc/keepalived/template/

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/controller/keepalived-ha.lua $(1)/usr/lib/lua/luci/controller/

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/keepalived-ha
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/model/cbi/keepalived-ha/keepalived-ha.lua $(1)/usr/lib/lua/luci/model/cbi/keepalived-ha/

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/keepalived-ha
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/keepalived-ha/status.htm $(1)/usr/lib/lua/luci/view/keepalived-ha/
endef

# 定义安装后脚本（自动启用服务）
define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/keepalived-ha enable
	echo "Keepalived HA 服务已自动启用开机启动"
	/etc/init.d/failover_watchdog enable
	echo "Failover Watchdog 服务已自动启用开机启动"
	/etc/init.d/keepalived disable
	echo "Keepalived HA 已取消Keepalived默认开机启动"
}
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
