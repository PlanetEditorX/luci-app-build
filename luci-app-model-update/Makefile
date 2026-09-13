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
	# ⚡ 依赖不带 "+"：依赖照样写进包元数据的 Depends 字段（设备端安装时会自动拉取），
	#    但编译本包时【不会】连带编译它们。
	#    带 "+" 的话会连带编译：git → libopenssl（openssl 全量编译）、
	#    yq / git-lfs → golang/host（Go 工具链，整条链里最慢的一段），实测 20 分钟以上，
	#    而且这些依赖包最后全被丢弃（CI 只上传本包的 ipk/apk），纯属白干。
	#    确实需要连依赖一起编译时，把下面的名字前面加回 "+" 即可。
	DEPENDS:=luci-base bash git git-lfs openssh-client openssh-keygen yq
	PKGARCH:=all
endef

# 安装后执行的脚本
define Package/$(PKG_NAME)/postinst
#!/bin/sh
if [ -x /usr/bin/git-lfs ]; then
    echo "Initializing git-lfs..."
    git lfs install --system --force || true
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
