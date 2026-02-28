################################################################################
#
# ainux-openwhale — OpenWhale AI agent platform
#
################################################################################

AINUX_OPENWHALE_VERSION = main
AINUX_OPENWHALE_SITE = https://github.com/viralcode/openwhale.git
AINUX_OPENWHALE_SITE_METHOD = git
AINUX_OPENWHALE_GIT_SUBMODULES = YES

AINUX_OPENWHALE_LICENSE = MIT
AINUX_OPENWHALE_DEPENDENCIES = nodejs sqlite

AINUX_OPENWHALE_INSTALL_TARGET = YES

define AINUX_OPENWHALE_BUILD_CMDS
	cd $(@D) && \
	npm install -g pnpm && \
	pnpm install && \
	pnpm approve-builds
endef

define AINUX_OPENWHALE_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/opt/ainux/openwhale
	cp -a $(@D)/* $(TARGET_DIR)/opt/ainux/openwhale/
	# Install systemd service
	install -D -m 0644 $(BR2_EXTERNAL_AINUX_PATH)/packages/openwhale/openwhale.service \
		$(TARGET_DIR)/usr/lib/systemd/system/openwhale.service
	# Install first-boot setup script
	install -D -m 0755 $(BR2_EXTERNAL_AINUX_PATH)/packages/openwhale/setup.sh \
		$(TARGET_DIR)/opt/ainux/bin/openwhale-setup
	# Enable the service
	mkdir -p $(TARGET_DIR)/etc/systemd/system/multi-user.target.wants
	ln -sf /usr/lib/systemd/system/openwhale.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/openwhale.service
endef

$(eval $(generic-package))
