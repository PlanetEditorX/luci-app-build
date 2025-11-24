include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-model-update
PKG_VERSION:=1.3
PKG_RELEASE:=1

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=utils
	CATEGORY:=Utilities
	TITLE:=Model Update Script with LuCI
	DEPENDS:=+luci-base +bash +git +git-lfs +openssh-client +openssh-keygen +yq
	PKGARCH:=all
endef

# 安装后执行的脚本
define Package/$(PKG_NAME)/postinst
#!/bin/sh
if [ -x /usr/bin/git-lfs ]; then
    echo "Initializing git-lfs..."
    git lfs install || true
fi
exit 0
endef

define Package/$(PKG_NAME)/description
LuCI interface for model update script.
Includes dependencies: git, git-lfs, openssh-client, openssh-keygen, yq.
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
