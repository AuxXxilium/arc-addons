#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ -d /var/packages/SurveillanceStation ]; then
    # Define the entries to be added
    ENTRIES=("0.0.0.0 synosurveillance.synology.com")

    # Loop over each entry
    for ENTRY in "${ENTRIES[@]}"
    do
        if [ -f /tmpRoot/etc/hosts ]; then
            # Check if the entry is already in the file
            if grep -Fxq "$ENTRY" /tmpRoot/etc/hosts; then
                echo "Entry $ENTRY already exists"
            else
                echo "Entry $ENTRY does not exist, adding now"
                echo "$ENTRY" >> /tmpRoot/etc/hosts
            fi
        fi
        if [ -f /tmpRoot/etc.defaults/hosts ]; then
            if grep -Fxq "$ENTRY" /tmpRoot/etc.defaults/hosts; then
                echo "Entry $ENTRY already exists"
            else
                echo "Entry $ENTRY does not exist, adding now"
                echo "$ENTRY" >> /tmpRoot/etc.defaults/hosts
            fi
        fi
    done

    SSPATH="/var/packages/SurveillanceStation"

    SO_FILE="${SSPATH}/target/lib/libssutils.so"
    ORG_FILE="${SSPATH}/target/lib/libssutils.so"
    MITM_FILE="${SSPATH}/target/lib/libssutils.mitm.so"
    JS_FILE="${SSPATH}/target/ui/sds.js"
    if [ ! -f "${SO_FILE}" ]; then
        echo "SSPatch: ${SO_FILE} does not exist"
        exit 1
    fi

    /usr/syno/bin/synopkg stop SurveillanceStation
    sleep 5

    # Check Sha256sum (DVA 92a8c8c75446daa7328a34acc67172e1f9f3af8229558766dbe5804a86c08a5e)
    if [ "$(sha256sum ${SO_FILE} | cut -d' ' -f1)" = "b0fafefe820aa8ecd577313dff2ae22cf41a6ddf44051f01670c3b92ee04224d" ]; then
        mv -f "${SO_FILE}" "${ORG_FILE}"
        cp -f "/usr/lib/libssutils.mitm.so" "${MITM_FILE}"
        patchelf --add-needed ${ORG_FILE} ${MITM_FILE}
        mv -f "${MITM_FILE}" "${SO_FILE}"
        echo "SSPatch: ${SO_FILE} is patched"
    else
        if [ -f "${ORG_FILE}" ]; then
            echo "SSPatch: ${SO_FILE} is already patched"
            exit 0
        else
            echo "SSPatch: version not supported"
            exit 1
        fi
    fi
    # Change owner and permissions
    chown SurveillanceStation:SurveillanceStation "${SO_FILE}"
    chmod 0644 "${SO_FILE}"
    echo -e "SSPatch: ${SO_FILE} permissions set"

    # Remove warning message
    sed -i 's/SYNO.API.RedirectToDSMByErrorCode=function(c){alert(SYNO.API.getErrorString(c));/SYNO.API.RedirectToDSMByErrorCode = () => { };/g' ${JS_FILE}
    echo -e "SSPatch: sds.js patched"

    sleep 5
    /usr/syno/bin/synopkg start SurveillanceStation
    echo -e "SSPatch: Successfull!"
    exit 0
else
    echo "SSPatch: SurveillanceStation not found"
    exit 1
fi