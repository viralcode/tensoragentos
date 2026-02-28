################################################################################
#
# ainux-chromium — Chromium built from source with WebMCP
#
################################################################################

AINUX_CHROMIUM_VERSION = 146.0.6000.0
AINUX_CHROMIUM_SITE = https://commondatastorage.googleapis.com/chromium-browser-official
AINUX_CHROMIUM_SOURCE = chromium-$(AINUX_CHROMIUM_VERSION).tar.xz

AINUX_CHROMIUM_LICENSE = BSD-3-Clause
AINUX_CHROMIUM_DEPENDENCIES = \
	mesa3d wayland wayland-protocols libdrm libinput \
	freetype harfbuzz fontconfig pango cairo \
	alsa-lib pipewire dbus libffi libpng libjpeg \
	openssl zlib libwebp xkeyboard-config libxkbcommon \
	nodejs

AINUX_CHROMIUM_INSTALL_TARGET = YES

# GN build args for AInux
define AINUX_CHROMIUM_CONFIGURE_CMDS
	cd $(@D) && \
	echo 'is_debug = false' > args.gn && \
	echo 'is_official_build = true' >> args.gn && \
	echo 'is_component_build = false' >> args.gn && \
	echo 'enable_nacl = false' >> args.gn && \
	echo 'use_ozone = true' >> args.gn && \
	echo 'ozone_platform = "wayland"' >> args.gn && \
	echo 'ozone_auto_platforms = false' >> args.gn && \
	echo 'ozone_platform_wayland = true' >> args.gn && \
	echo 'ozone_platform_x11 = false' >> args.gn && \
	echo 'use_system_freetype = true' >> args.gn && \
	echo 'use_system_harfbuzz = true' >> args.gn && \
	echo 'use_system_libdrm = true' >> args.gn && \
	echo 'use_system_libffi = true' >> args.gn && \
	echo 'use_system_wayland = true' >> args.gn && \
	echo 'use_system_minigbm = true' >> args.gn && \
	echo 'enable_webmcp = true' >> args.gn && \
	echo 'enable_experimental_web_platform_features = true' >> args.gn && \
	echo 'proprietary_codecs = true' >> args.gn && \
	echo 'ffmpeg_branding = "Chrome"' >> args.gn && \
	echo 'use_vaapi = true' >> args.gn && \
	echo 'use_pulseaudio = false' >> args.gn && \
	echo 'use_pipewire = true' >> args.gn && \
	echo 'rtc_use_pipewire = true' >> args.gn && \
	echo 'chrome_pgo_phase = 0' >> args.gn && \
	echo 'symbol_level = 0' >> args.gn && \
	echo 'blink_symbol_level = 0' >> args.gn && \
	echo 'v8_symbol_level = 0' >> args.gn && \
	gn gen out/AInux --args="$$(cat args.gn)"
endef

# Apply AInux patches before configure
define AINUX_CHROMIUM_PATCH_CMDS
	for p in $(BR2_EXTERNAL_AINUX_PATH)/packages/chromium/patches/*.patch; do \
		patch -p1 -d $(@D) < $$p || true; \
	done
endef

define AINUX_CHROMIUM_BUILD_CMDS
	cd $(@D) && ninja -C out/AInux chrome
endef

define AINUX_CHROMIUM_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/opt/ainux/chromium
	cp -a $(@D)/out/AInux/chrome $(TARGET_DIR)/opt/ainux/chromium/
	cp -a $(@D)/out/AInux/*.pak $(TARGET_DIR)/opt/ainux/chromium/
	cp -a $(@D)/out/AInux/*.dat $(TARGET_DIR)/opt/ainux/chromium/ 2>/dev/null || true
	cp -a $(@D)/out/AInux/*.bin $(TARGET_DIR)/opt/ainux/chromium/ 2>/dev/null || true
	cp -a $(@D)/out/AInux/icudtl.dat $(TARGET_DIR)/opt/ainux/chromium/ 2>/dev/null || true
	cp -a $(@D)/out/AInux/locales $(TARGET_DIR)/opt/ainux/chromium/ 2>/dev/null || true
	cp -a $(@D)/out/AInux/v8_context_snapshot.bin $(TARGET_DIR)/opt/ainux/chromium/ 2>/dev/null || true
	# Install the ainux-browser wrapper
	install -D -m 0755 $(BR2_EXTERNAL_AINUX_PATH)/packages/chromium/ainux-browser \
		$(TARGET_DIR)/opt/ainux/bin/ainux-browser
endef

$(eval $(generic-package))
