#!/usr/bin/env bash
#
# Copyright (C) 2024 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Allow VideoStation Downgrade on DSM 7.2.2
/usr/syno/bin/synosetkeyvalue /etc.defaults/synopackageslimit.conf VideoStation "3.1.0-3153"
/usr/syno/bin/synosetkeyvalue /etc/synopackageslimit.conf VideoStation "3.1.0-3153"
# Allow AME Downgrade on DSM 7.2.2
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


# Prevent AME from updating
if [ -d "/var/packages/CodecPack" ]; then
    /usr/syno/bin/synosetkeyvalue "/var/packages/CodecPack/INFO" version "30.1.0-3005"
fi
# Prevent VideoStation from updating
if [ -d "/var/packages/VideoStation" ]; then
    /usr/syno/bin/synosetkeyvalue "/var/packages/VideoStation/INFO" version "30.1.0-3153"
fi
# Prevent Surveillance Station from updating
if [ -d "/var/packages/SurveillanceStation" ]; then
    /usr/syno/bin/synosetkeyvalue "/var/packages/SurveillanceStation/INFO" version "90.2.0-11289"
fi
# Prevent Media Server from updating
if [ -d "/var/packages/MediaServer" ]; then
    /usr/syno/bin/synosetkeyvalue "/var/packages/MediaServer/INFO" version "20.1.0-3304"
fi
# Prevent Synology Photos from updating
if [ -d "/var/packages/Synology Photos" ]; then
    /usr/syno/bin/synosetkeyvalue "/var/packages/Synology Photos/INFO" version "10.6.2-0710"
fi