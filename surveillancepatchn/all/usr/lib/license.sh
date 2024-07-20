#!/bin/bash
while true
do
sleep 3600
synopkg restart SurveillanceStation
/var/packages/SurveillanceStation/target/bin/ssctl start

done
