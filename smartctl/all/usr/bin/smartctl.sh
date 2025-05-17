#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

args=()
for arg in "$@"; do [[ "$arg" = "ata" ]] && args+=("auto") || args+=("$arg"); done
smartctl.bak "${args[@]}"
