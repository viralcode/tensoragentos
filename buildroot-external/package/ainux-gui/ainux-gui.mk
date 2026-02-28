################################################################################
#
# ainux-gui — Agentic GUI (React app built with Vite)
#
################################################################################

AINUX_GUI_VERSION = 0.1.0
AINUX_GUI_SITE = $(BR2_EXTERNAL_AINUX_PATH)/packages/gui
AINUX_GUI_SITE_METHOD = local

AINUX_GUI_LICENSE = MIT
AINUX_GUI_DEPENDENCIES = nodejs ainux-openwhale

AINUX_GUI_INSTALL_TARGET = YES

define AINUX_GUI_BUILD_CMDS
	cd $(@D) && npm install && npm run build
endef

define AINUX_GUI_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/opt/ainux/gui
	cp -a $(@D)/dist/* $(TARGET_DIR)/opt/ainux/gui/
endef

$(eval $(generic-package))
