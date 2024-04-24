#!/usr/bin/env bash

if [ -d /var/packages/SurveillanceStation ]; then
    SSPATH="/var/packages/SurveillanceStation"
    PATHROOT="${SSPATH}/target"
    PATHLIB="${PATHROOT}/lib"
    PATHSCRIPTS="${PATHROOT}/scripts"
    SPATCH="/usr/lib"

    rm -f "${PATHLIB}/libssutils.so"
    cp -f "${SPATCH}/libssutils.so" "${PATHLIB}/libssutils.so"
    chown SurveillanceStation:SurveillanceStation "${PATHLIB}/libssutils.so"
    chmod 0644 "${PATHLIB}/libssutils.so"

    rm -f "${PATHSCRIPTS}/S82surveillance.sh"
    cp -f "${SPATCH}/S82surveillance.sh" "${PATHSCRIPTS}/S82surveillance.sh"
    chown SurveillanceStation:SurveillanceStation "${PATHSCRIPTS}/S82surveillance.sh"
    chmod 0755 "${PATHSCRIPTS}/S82surveillance.sh"

    rm -f "${PATHSCRIPTS}/license.sh"
    cp -f "${SPATCH}/license.sh" "${PATHSCRIPTS}/license.sh"
    chown SurveillanceStation:SurveillanceStation "${PATHSCRIPTS}/license.sh"
    chmod 0777 "${PATHSCRIPTS}/license.sh"

    echo -e "Surveillance Patch: Successfull!"
fi

exit 0