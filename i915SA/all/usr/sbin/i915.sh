#!/usr/bin/env bash

if [ -f "/usr/i915/lib/modules/i915.ko"]; then
    insmod /usr/i915/lib/modules/i2c-algo-bit.ko
    insmod /usr/i915/lib/modules/backport-sa6400-export.ko
    insmod /usr/i915/lib/modules/backport-dma-buf.ko
    insmod /usr/i915/lib/modules/hdmi.ko
    insmod /usr/i915/lib/modules/backlight.ko
    insmod /usr/i915/lib/modules/drm_panel_orientation_quirks.ko
    insmod /usr/i915/lib/modules/drm.ko
    insmod /usr/i915/lib/modules/fbdev.ko
    insmod /usr/i915/lib/modules/fbcore.ko
    insmod /usr/i915/lib/modules/drm_kms_helper.ko
    insmod /usr/i915/lib/modules/backport-sa6400.ko
    insmod /usr/i915/lib/modules/drm_mipi_dsi.ko
    insmod /usr/i915/lib/modules/video.ko
    insmod /usr/i915/lib/modules/i915.ko enable_guc=2
elif [ -f "/tmpRoot/usr/i915/lib/modules/i915.ko"]; then
    insmod /tmpRoot/usr/i915/lib/modules/i2c-algo-bit.ko
    insmod /tmpRoot/usr/i915/lib/modules/backport-sa6400-export.ko
    insmod /tmpRoot/usr/i915/lib/modules/backport-dma-buf.ko
    insmod /tmpRoot/usr/i915/lib/modules/hdmi.ko
    insmod /tmpRoot/usr/i915/lib/modules/backlight.ko
    insmod /tmpRoot/usr/i915/lib/modules/drm_panel_orientation_quirks.ko
    insmod /tmpRoot/usr/i915/lib/modules/drm.ko
    insmod /tmpRoot/usr/i915/lib/modules/fbdev.ko
    insmod /tmpRoot/usr/i915/lib/modules/fbcore.ko
    insmod /tmpRoot/usr/i915/lib/modules/drm_kms_helper.ko
    insmod /tmpRoot/usr/i915/lib/modules/backport-sa6400.ko
    insmod /tmpRoot/usr/i915/lib/modules/drm_mipi_dsi.ko
    insmod /tmpRoot/usr/i915/lib/modules/video.ko
    insmod /tmpRoot/usr/i915/lib/modules/i915.ko enable_guc=2
fi