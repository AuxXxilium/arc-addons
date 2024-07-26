#!/usr/bin/env bash

if [ -d /var/packages/SurveillanceStation ]; then
    # Define the entries to be added
    ENTRIES=("0.0.0.0 synosurveillance.synology.com")

    # Loop over each entry
    for ENTRY in "${ENTRIES[@]}"
    do
    if [ -f /etc/hosts ]; then
        # Check if the entry is already in the file
        if grep -Fxq "$ENTRY" /etc/hosts; then
            echo "Entry $ENTRY already exists"
        else
            echo "Entry $ENTRY does not exist, adding now"
            echo "$ENTRY" >> /etc/hosts
        fi
    fi
    if [ -f /etc.defaults/hosts ]; then
        if grep -Fxq "$ENTRY" /etc.defaults/hosts; then
            echo "Entry $ENTRY already exists"
        else
            echo "Entry $ENTRY does not exist, adding now"
            echo "$ENTRY" >> /etc.defaults/hosts
        fi
    fi
    done

    SSPATH="/var/packages/SurveillanceStation"
    PATHROOT="${SSPATH}/target"
    PATHLIB="${PATHROOT}/lib"
    PATHSCRIPTS="${PATHROOT}/scripts"
    SPATCH="/usr/lib"
    SPATCHBIN="/usr/bin"

    /usr/syno/bin/synopkg stop SurveillanceStation
    sleep 5

    rm -f "${PATHLIB}/libssutils.so"
    cp -f "${SPATCH}/libssutils.so" "${PATHLIB}/libssutils.so"
    chown SurveillanceStation:SurveillanceStation "${PATHLIB}/libssutils.so"
    chmod 0644 "${PATHLIB}/libssutils.so"

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