#!/usr/bin/env ash

scriptver="23.6.1"
script=Surveillance
repo="AuxXxilium/arc-addons"

PATH1="/var/packages/SurveillanceStation/target/lib"
PATH2="/var/packages/SurveillanceStation/target/scripts"
if [ -f "/usr/lib/libssutils.so" ]; then
    SPATCH="/usr/lib"
    surveillancepatch
elif [ -f "/tmpRoot/usr/lib/libssutils.so" ]; then
    SPATCH="/tmpRoot/usr/lib"
    surveillancepatch
else
    echo -e "Surveillance Patch: Files not found!"
fi

function surveillancepatch () {
/usr/syno/bin/synopkg stop SurveillanceStation
sleep 15

cp -f ${PATH1}/libssutils.so ${PATH1}/libssutils.so.bak
rm -f ${PATH1}/libssutils.so
cp -f ${SPATCH}/libssutils.so ${PATH1}/libssutils.so
chown SurveillanceStation:SurveillanceStation ${PATH1}/libssutils.so
chmod 0644 ${PATH1}/libssutils.so

cp -f ${PATH2}/S82surveillance.sh ${PATH2}/S82surveillance.sh.bak
rm -f ${PATH2}/S82surveillance.sh
cp -f ${SPATCH}/S82surveillance.sh ${PATH2}/S82surveillance.sh
chown SurveillanceStation:SurveillanceStation ${PATH2}/S82surveillance.sh
chmod 0755 ${PATH2}/S82surveillance.sh

rm -f ${PATH2}/license.sh
cp -f ${SPATCH}/license.sh ${PATH2}/license.sh 
chown SurveillanceStation:SurveillanceStation ${PATH2}/license.sh
chmod 0777 ${PATH2}/license.sh

echo -e "Surveillance Patch: Successfull!"

sleep 5
/usr/syno/bin/synopkg start SurveillanceStation
}