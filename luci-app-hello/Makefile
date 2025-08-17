include $(TOPDIR)/rules.mk
PKG_NAME:=luci-app-hello
PKG_VERSION:=1.0
PKG_RELEASE:=1
include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/luci/luci.mk

define Package/$(PKG_NAME)
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=3. System
	TITLE:=LuCI Hello World
	DEPENDS:=+luci-base
	PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
	Simple Hello World for LuCI
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/hello
	$(CP) ./files/usr/lib/lua/luci/controller/hello.lua $(1)/usr/lib/lua/luci/controller/
	$(CP) ./files/usr/lib/lua/luci/view/hello/index.htm $(1)/usr/lib/lua/luci/view/hello/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))