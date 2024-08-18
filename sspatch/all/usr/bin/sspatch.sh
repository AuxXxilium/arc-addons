#!/usr/bin/env bash

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

    SO_FILE="${SSPATH}/target/lib/libssutils.so"
    if [ ! -f "${SO_FILE}" ]; then
        echo "SSPatch: libssutils.so does not exist"
        exit 1
    fi

    /usr/syno/bin/synopkg stop SurveillanceStation
    sleep 5

    # Check Sha256sum
    if [ "$(sha256sum "${SO_FILE}" | cut -d' ' -f1)" = "81b64d65f4a2a65626f9280ba43ea43f031a239af3152b859b79e1b5124cc6e3" ]; then
        PATCH="8548ffffff41be43000000e93dffffff/8548ffffff41be7b000000e93dffffff"
        cp -f "${SO_FILE}" "${SO_FILE}.bak"
        cp -f "${SO_FILE}" "${SO_FILE}.tmp"
        xxd -c $(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c) -p "${SO_FILE}.tmp" 2>/dev/null |
            sed "s/${PATCH}/" |
            xxd -r -p >"${SO_FILE}" 2>/dev/null
        rm -f "${SO_FILE}.tmp"
        echo "SSPatch: libssutils.so is patched"
    elif [ "$(sha256sum "${SO_FILE}" | cut -d' ' -f1)" = "b0fafefe820aa8ecd577313dff2ae22cf41a6ddf44051f01670c3b92ee04224d" ]; then
        PATCH="850b010000e8b684e5ff83f80141bc43/850b010000e8b684e5ff83f80141bc7b"
        cp -f "${SO_FILE}" "${SO_FILE}.bak"
        cp -f "${SO_FILE}" "${SO_FILE}.tmp"
        xxd -c $(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c) -p "${SO_FILE}.tmp" 2>/dev/null |
            sed "s/${PATCH}/" |
            xxd -r -p >"${SO_FILE}" 2>/dev/null
        rm -f "${SO_FILE}.tmp"
        echo "SSPatch: libssutils.so is patched"
    else
        if [ -f "${SO_FILE}.bak" ]; then
            echo "SSPatch: libssutils.so is already patched"
            exit 0
        else
            echo "SSPatch: version not supported"
            exit 1
        fi
    fi
    chown SurveillanceStation:SurveillanceStation "${SO_FILE}"
    chmod 0644 "${SO_FILE}"

    rm -f "${PATHSCRIPTS}/S82surveillance.sh"
    cp -f "${SPATCHBIN}/S82surveillance.sh" "${PATHSCRIPTS}/S82surveillance.sh"
    chown SurveillanceStation:SurveillanceStation "${PATHSCRIPTS}/S82surveillance.sh"
    chmod 0755 "${PATHSCRIPTS}/S82surveillance.sh"

    rm -f "${PATHSCRIPTS}/license.sh"
    cp -f "${SPATCHBIN}/license.sh" "${PATHSCRIPTS}/license.sh"
    chown SurveillanceStation:SurveillanceStation "${PATHSCRIPTS}/license.sh"
    chmod 0777 "${PATHSCRIPTS}/license.sh"

    echo -e "Surveillance Patch: Successfull!"

    sleep 5
    /usr/syno/bin/synopkg start SurveillanceStation
fi
exit 0