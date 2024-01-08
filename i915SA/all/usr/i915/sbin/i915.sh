#!/usr/bin/env bash

if [ -f "/usr/i915/lib/modules/i915.ko" ]; then
    rmmod /usr/lib/modules/i2c-algo-bit.ko
    rmmod /usr/lib/modules/backport-sa6400-export.ko
    rmmod /usr/lib/modules/backport-dma-buf.ko
    rmmod /usr/lib/modules/hdmi.ko
    rmmod /usr/lib/modules/backlight.ko
    rmmod /usr/lib/modules/drm_panel_orientation_quirks.ko
    rmmod /usr/lib/modules/drm.ko
    rmmod /usr/lib/modules/fbdev.ko
    rmmod /usr/lib/modules/fbcore.ko
    rmmod /usr/lib/modules/drm_kms_helper.ko
    rmmod /usr/lib/modules/backport-sa6400.ko
    rmmod /usr/lib/modules/drm_mipi_dsi.ko
    rmmod /usr/lib/modules/video.ko
    rmmod /usr/lib/modules/i915.ko
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
    echo "i915SA: Exec direct and reload Modules."
else
    echo "i915SA: No Modules found."
fi