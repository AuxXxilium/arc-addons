#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
    if [ -d /tmpRoot/var/packages/SurveillanceStation ]; then
        echo "Installing addon sspatch - ${1}"
        mkdir -p "/tmpRoot/usr/arc/addons/"
        cp -vf "${0}" "/tmpRoot/usr/arc/addons/"

        SO_FILE="/tmpRoot/var/packages/SurveillanceStation/target/lib/libssutils.so"
        if [ ! -f "${SO_FILE}" ]; then
            echo "SSPatch: libssutils.so does not exist"
            exit 0
        fi

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

        # Check Sha256sum
        if [ "$(sha256sum "${SO_FILE}" | cut -d' ' -f1)" = "81b64d65f4a2a65626f9280ba43ea43f031a239af3152b859b79e1b5124cc6e3" ]; then
            PATCH="8548ffffff41be43000000e93dffffff/8548ffffff41be7b000000e93dffffff"
            cp -vf "${SO_FILE}" "${SO_FILE}.bak"
            cp -f "${SO_FILE}" "${SO_FILE}.tmp"
            xxd -c $(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c) -p "${SO_FILE}.tmp" 2>/dev/null |
                sed "s/${PATCH}/" |
                xxd -r -p >"${SO_FILE}" 2>/dev/null
            rm -f "${SO_FILE}.tmp"
            echo "SSPatch: libssutils.so is patched"
        elif [ "$(sha256sum "${SO_FILE}" | cut -d' ' -f1)" = "b0fafefe820aa8ecd577313dff2ae22cf41a6ddf44051f01670c3b92ee04224d" ]; then
            PATCH="850b010000e8b684e5ff83f80141bc43/850b010000e8b684e5ff83f80141bc7b"
            cp -vf "${SO_FILE}" "${SO_FILE}.bak"
            cp -f "${SO_FILE}" "${SO_FILE}.tmp"
            xxd -c $(xxd -p "${SO_FILE}.tmp" 2>/dev/null | wc -c) -p "${SO_FILE}.tmp" 2>/dev/null |
                sed "s/${PATCH}/" |
                xxd -r -p >"${SO_FILE}" 2>/dev/null
            rm -f "${SO_FILE}.tmp"
            echo "SSPatch: libssutils.so is patched"
        else
            if [ -f "${SO_FILE}.bak" ]; then
                echo "SSPatch: libssutils.so is already patched"
            else
                echo "SSPatch: version not supported"
            fi
        fi
        cp -vf /usr/bin/license.sh /tmpRoot/usr/bin/license.sh
        cp -vf /usr/bin/S82surveillance.sh /tmpRoot/usr/bin/S82surveillance.sh
    fi
elif [ "${1}" = "uninstall" ]; then
  echo "Installing addon sspatch - ${1}"
  # To-Do
fi