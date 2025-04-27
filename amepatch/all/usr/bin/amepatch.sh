#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Check if /usr/bin/arcsu exists
ARCSU=""
if [ -x "/usr/bin/arcsu" ]; then
  ARCSU="/usr/bin/arcsu"
fi

AMEVERSION="$(grep -oP '(?<=version=").*(?=")' /var/packages/CodecPack/INFO | head -n1 | sed -E 's/^0*([0-9])0/\1/')" || true

if [ -d "/var/packages/CodecPack" ] && [ "${AMEVERSION}" = "3.1.0-3005" ]; then
    AME_APPARMOR="/var/packages/CodecPack/target/apparmor"
    [ -d "$AME_APPARMOR" ] && ${ARCSU} /usr/syno/etc/rc.sysv/apparmor.sh remove_packages_profile 0 CodecPack && ${ARCSU} mv -f "$AME_APPARMOR" "${AME_APPARMOR}.bak" || true

    AME_PATH="/var/packages/CodecPack/target/usr"
    AME_SO="${AME_PATH}/lib/libsynoame-license.so"
    AME_SO_BAK="${AME_PATH}/lib/libsynoame-license.so.orig"
    AME_LIC="/usr/syno/etc/license/data/ame/offline_license.json"
    AME_LIC_BAK="/usr/syno/etc/license/data/ame/offline_license.json.orig"
    
    [ ! -f "${AME_SO_BAK}" ] && ${ARCSU} cp -pf "${AME_SO}" "${AME_SO_BAK}"
    [ ! -f "${AME_LIC_BAK}" ] && ${ARCSU} cp -pf "${AME_LIC}" "${AME_LIC_BAK}"
    
    AME_HASH="$(${ARCSU} md5sum -b "${AME_SO}" | awk '{print $1}')"
    
    case "$AME_HASH" in
        "fcc1084f4eadcf5855e6e8494fb79e23" | "923fd0d58e79b7dc0f6c377547545930")
            LIC_HEX_VALUES=('1F28' '48F5' '4921' '4953' '4975' '9AC8')
            LIC_CONTENT='[{"appType": 14, "appName": "ame", "follow": ["device"], "server_time": 1666000000, "registered_at": 1651000000, "expireTime": 0, "status": "valid", "firstActTime": 1651000001, "extension_gid": null, "licenseCode": "0", "duration": 1576800000, "attribute": {"codec": "hevc", "type": "free"}, "licenseContent": 1}, {"appType": 14, "appName": "ame", "follow": ["device"], "server_time": 1666000000, "registered_at": 1651000000, "expireTime": 0, "status": "valid", "firstActTime": 1651000001, "extension_gid": null, "licenseCode": "0", "duration": 1576800000, "attribute": {"codec": "aac", "type": "free"}, "licenseContent": 1}]'
            ;;
        "09e3adeafe85b353c9427d93ef0185e9")
            LIC_HEX_VALUES=('3718' '60A5' '60D1' '6111' '6137' 'B5F0')
            LIC_CONTENT='[{"attribute": {"codec": "hevc", "type": "free"}, "status": "valid", "extension_gid": null, "expireTime": 0, "appName": "ame", "follow": ["device"], "duration": 1576800000, "appType": 14, "licenseContent": 1, "registered_at": 1649315995, "server_time": 1685421618, "firstActTime": 1649315995, "licenseCode": "0"}, {"attribute": {"codec": "aac", "type": "free"}, "status": "valid", "extension_gid": null, "expireTime": 0, "appName": "ame", "follow": ["device"], "duration": 1576800000, "appType": 14, "licenseContent": 1, "registered_at": 1649315995, "server_time": 1685421618, "firstActTime": 1649315995, "licenseCode": "0"}]'
            ;;
        *)
            echo "AME Patch: MD5 mismatch - already patched or unsupported version!"
            exit 0
            ;;
    esac

    LIC_VALUES=('669066909066906690' 'B801000000' '30')
    LIC_INDICES=(0 1 1 1 1 2)

    for ((i = 0; i < ${#LIC_HEX_VALUES[@]}; i++)); do
        offset=$(( 0x${LIC_HEX_VALUES[i]} + 0x8000 ))
        value=${LIC_VALUES[LIC_INDICES[i]]}
        printf '%s' "$value" | xxd -r -p | ${ARCSU} dd of="${AME_SO}" bs=1 seek="$offset" conv=notrunc
        if [[ $? -ne 0 ]]; then
            echo -e "AME Patch: Error while writing to file!"
            exit 1
        fi
    done

    ${ARCSU} mkdir -p "$(dirname "${AME_LIC}")"
    ${ARCSU} rm -f "${AME_LIC}"
    echo "${LIC_CONTENT}" | ${ARCSU} tee "${AME_LIC}" >/dev/null

    if ${ARCSU} "${AME_PATH}"/bin/synoame-bin-check-license; then
        ${ARCSU} "${AME_PATH}"/bin/synoame-bin-auto-install-needed-codec
        echo -e "AME Patch: Successful!"
    else
        [ -f "${AME_SO_BAK}" ] && ${ARCSU} cp -pf "${AME_SO_BAK}" "${AME_SO}" || true
        [ -f "${AME_LIC_BAK}" ] && ${ARCSU} cp -pf "${AME_LIC_BAK}" "${AME_LIC}" || true
        echo -e "AME Patch: Unsuccessful!"
        exit 1
    fi
fi

exit 0