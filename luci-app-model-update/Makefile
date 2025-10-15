include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-model-update
PKG_VERSION:=1.2
PKG_RELEASE:=1

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=utils
	CATEGORY:=Utilities
	TITLE:=Model Update Script with LuCI
	DEPENDS:=+luci-base +bash +git
	PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
	Auto update model and control via LuCI web interface.
endef

define Build/Compile
	# No compilation needed
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/model-update $(1)/etc/init.d/model-update

	$(INSTALL_DIR) $(1)/etc/openclash
	$(INSTALL_BIN) ./files/etc/openclash/model-update.sh $(1)/etc/openclash/model-update.sh

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/99-model-update $(1)/etc/uci-defaults/99-model-update

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/model-update.lua $(1)/usr/lib/lua/luci/controller/model-update.lua

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view
	$(INSTALL_BIN) ./luasrc/view/model-update.htm $(1)/usr/lib/lua/luci/view/model-update.htm
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
