################################################################################
#
# ainux-shell — Wayland session that boots into the agentic GUI
#
################################################################################

AINUX_SHELL_VERSION = 0.1.0
AINUX_SHELL_SITE = $(BR2_EXTERNAL_AINUX_PATH)/packages/gui
AINUX_SHELL_SITE_METHOD = local

AINUX_SHELL_LICENSE = MIT
AINUX_SHELL_DEPENDENCIES = cage ainux-chromium ainux-openwhale

AINUX_SHELL_INSTALL_TARGET = YES

define AINUX_SHELL_INSTALL_TARGET_CMDS
	# Install the shell launcher script
	install -D -m 0755 $(BR2_EXTERNAL_AINUX_PATH)/packages/gui/ainux-shell \
		$(TARGET_DIR)/opt/ainux/bin/ainux-shell

	# Install the AInux kernel (Node.js orchestrator)
	mkdir -p $(TARGET_DIR)/opt/ainux/core
	cp -a $(BR2_EXTERNAL_AINUX_PATH)/packages/core/src/* \
		$(TARGET_DIR)/opt/ainux/core/

	# Install shell systemd service
	install -D -m 0644 $(BR2_EXTERNAL_AINUX_PATH)/rootfs-overlay/etc/systemd/system/ainux-shell.service \
		$(TARGET_DIR)/usr/lib/systemd/system/ainux-shell.service

	# Install AInux kernel systemd service
	install -D -m 0644 $(BR2_EXTERNAL_AINUX_PATH)/rootfs-overlay/etc/systemd/system/ainux-kernel.service \
		$(TARGET_DIR)/usr/lib/systemd/system/ainux-kernel.service

	# Enable services
	mkdir -p $(TARGET_DIR)/etc/systemd/system/graphical.target.wants
	ln -sf /usr/lib/systemd/system/ainux-shell.service \
		$(TARGET_DIR)/etc/systemd/system/graphical.target.wants/ainux-shell.service
	ln -sf /usr/lib/systemd/system/ainux-kernel.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/ainux-kernel.service
endef

$(eval $(generic-package))
