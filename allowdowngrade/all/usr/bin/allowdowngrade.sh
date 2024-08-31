#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
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