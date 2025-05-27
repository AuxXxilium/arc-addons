#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Allow VideoStation Downgrade on DSM 7.2.2
/usr/syno/bin/synosetkeyvalue /etc.defaults/synopackageslimit.conf VideoStation "3.1.0-3153"
/usr/syno/bin/synosetkeyvalue /etc/synopackageslimit.conf VideoStation "3.1.0-3153"
# Allow CodecPack Downgrade on DSM 7.2.2
/usr/syno/bin/synosetkeyvalue /etc.defaults/synopackageslimit.conf CodecPack "3.1.0-3005"
/usr/syno/bin/synosetkeyvalue /etc/synopackageslimit.conf CodecPack "3.1.0-3005"
# Allow Surveillance Station Downgrade on DSM 7.2.2
/usr/syno/bin/synosetkeyvalue /etc.defaults/synopackageslimit.conf SurveillanceStation "9.2.0-11289"
/usr/syno/bin/synosetkeyvalue /etc/synopackageslimit.conf SurveillanceStation "9.2.0-11289"
# Allow Media Server Downgrade on DSM 7.2.2
/usr/syno/bin/synosetkeyvalue /etc.defaults/synopackageslimit.conf MediaServer "2.1.0-3304"
/usr/syno/bin/synosetkeyvalue /etc/synopackageslimit.conf MediaServer "2.1.0-3304"
# Allow Synology Photos Downgrade on DSM 7.2.2
/usr/syno/bin/synosetkeyvalue /etc.defaults/synopackageslimit.conf SynologyPhotos "1.6.2-0710"
/usr/syno/bin/synosetkeyvalue /etc/synopackageslimit.conf SynologyPhotos "1.6.2-0710"


# Prevent CodecPack from updating
if [ -d "/var/packages/CodecPack" ]; then
    VERSION="$(grep -oP '(?<=version=").*(?=")' "/var/packages/CodecPack/INFO" | head -n1 | sed -E 's/^0*([0-9])0/\1/')"
    if [ "${VERSION}" = "3.1.0-3005" ]; then
        /usr/syno/bin/synosetkeyvalue "/var/packages/CodecPack/INFO" version "30.1.0-3005"
    fi
fi
# Prevent VideoStation from updating
if [ -d "/var/packages/VideoStation" ]; then
    VERSION="$(grep -oP '(?<=version=").*(?=")' "/var/packages/VideoStation/INFO" | head -n1 | sed -E 's/^0*([0-9])0/\1/')"
    if [ "${VERSION}" = "3.1.0-3153" ]; then
        /usr/syno/bin/synosetkeyvalue "/var/packages/VideoStation/INFO" version "30.1.0-3153"
    fi
fi
# Prevent Surveillance Station from updating
if [ -d "/var/packages/SurveillanceStation" ]; then
    VERSION="$(grep -oP '(?<=version=").*(?=")' "/var/packages/SurveillanceStation/INFO" | head -n1 | sed -E 's/^0*([0-9])0/\1/')"
    if [ "${VERSION}" = "9.2.0-11289" ]; then
        /usr/syno/bin/synosetkeyvalue "/var/packages/SurveillanceStation/INFO" version "90.2.0-11289"
    fi
fi
# Prevent Media Server from updating
if [ -d "/var/packages/MediaServer" ]; then
    VERSION="$(grep -oP '(?<=version=").*(?=")' "/var/packages/MediaServer/INFO" | head -n1 | sed -E 's/^0*([0-9])0/\1/')"
    if [ "${VERSION}" = "2.1.0-3304" ]; then
        /usr/syno/bin/synosetkeyvalue "/var/packages/MediaServer/INFO" version "20.1.0-3304"
    fi
fi
# Prevent Synology Photos from updating
if [ -d "/var/packages/Synology\ Photos" ]; then
    VERSION="$(grep -oP '(?<=version=").*(?=")' "/var/packages/Synology\ Photos/INFO" | head -n1 | sed -E 's/^0*([0-9])/\1/')"
    if [ "${VERSION}" = "1.6.2-0710" ]; then
        /usr/syno/bin/synosetkeyvalue "/var/packages/Synology\ Photos/INFO" version "10.6.2-0710"
    fi
fi
exit 0