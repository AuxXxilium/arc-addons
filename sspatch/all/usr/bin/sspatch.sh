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
    PATHSCRIPTS="${SSPATH}/target/scripts"
    SPATCHBIN="/usr/bin"

    SO_FILE="${SSPATH}/target/lib/libssutils"
    if [ ! -f "${SO_FILE}.so" ]; then
        echo "SSPatch: libssutils.so does not exist"
        exit 1
    fi

    /usr/syno/bin/synopkg stop SurveillanceStation
    sleep 5

    # Check Sha256sum
if [ "$(sha256sum "${SO_FILE}" | cut -d' ' -f1)" = "b0fafefe820aa8ecd577313dff2ae22cf41a6ddf44051f01670c3b92ee04224d" ]; then
        mv -f "${SO_FILE}.so" "${SO_FILE}.org.so"
        cp -f "/usr/lib/libssutils.mitm.so" "${SO_FILE}.mitm.so"
        patchelf --add-needed /var/packages/SurveillanceStation/target/lib/libssutils.org.so /var/packages/SurveillanceStation/target/lib/libssutils.mitm.so
        mv -f "${SO_FILE}.mitm.so" "${SO_FILE}.so"
        echo "SSPatch: libssutils.so is patched"
    else
        if [ -f "${SO_FILE}.org.so" ]; then
            echo "SSPatch: libssutils.so is already patched"
            exit 0
        else
            echo "SSPatch: version not supported"
            exit 1
        fi
    fi
    chown SurveillanceStation:SurveillanceStation "${SO_FILE}"
    chmod 0644 "${SO_FILE}"

    echo -e "SSPatch: Successfull!"

    sleep 5
    /usr/syno/bin/synopkg start SurveillanceStation
    exit 0
else
    echo "SSPatch: SurveillanceStation not found"
    exit 1
fi