#!/usr/bin/env ash

/usr/syno/bin/synopkg stop SurveillanceStation
sleep 15

PATH1="/var/packages/SurveillanceStation/target/lib"
PATH2="/var/packages/SurveillanceStation/target/scripts"
SPATCH="/usr/lib"

cp -vf ${PATH1}/libssutils.so ${PATH1}/libssutils.so.bak
rm -f ${PATH1}/libssutils.so
cp -vf ${SPATCH}/libssutils.so ${PATH1}/libssutils.so
chown SurveillanceStation:SurveillanceStation ${PATH1}/libssutils.so
chmod 0644 ${PATH1}/libssutils.so

cp -vf ${PATH2}/S82surveillance.sh ${PATH2}/S82surveillance.sh.bak
rm -f ${PATH2}/S82surveillance.sh
cp -vf ${SPATCH}/S82surveillance.sh ${PATH2}/S82surveillance.sh
chown SurveillanceStation:SurveillanceStation ${PATH2}/S82surveillance.sh
chmod 0755 ${PATH2}/S82surveillance.sh

rm -f ${PATH2}/license.sh
cp -vf ${SPATCH}/license.sh ${PATH2}/license.sh 
chown SurveillanceStation:SurveillanceStation ${PATH2}/license.sh
chmod 0777 ${PATH2}/license.sh

echo -e "Surveillance Patch: Successfull!"

sleep 5
/usr/syno/bin/synopkg start SurveillanceStation