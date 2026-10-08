include $(TOPDIR)/rules.mk

PKG_VERSION:=1.26.1

LUCI_TITLE:=LuCI Support for nikki
LUCI_DEPENDS:=+luci-base +nikki

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature

# Building from a Windows/macOS shared folder (e.g. a /mnt/d checkout under WSL) makes every
# source file look like 0666/0777.  luci.mk copies the app tree with $(CP), so those modes end
# up inside the .apk, and rpcd refuses to load o+w plugin/ACL files -- the whole LuCI app then
# disappears with "Object not found" (RPCError -32000).  Normalise the modes on install so the
# package is safe no matter where it was built.
define Package/luci-app-nikki/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	chmod 0755 /usr/share/rpcd/ucode/luci.nikki 2>/dev/null
	chmod 0644 /usr/share/rpcd/acl.d/luci-app-nikki.json 2>/dev/null
	chmod 0644 /usr/share/luci/menu.d/luci-app-nikki.json 2>/dev/null
	chmod 0644 /www/luci-static/resources/view/nikki/*.js 2>/dev/null
	rm -f /tmp/luci-indexcache* 2>/dev/null
	/etc/init.d/rpcd restart 2>/dev/null
}
exit 0
endef
