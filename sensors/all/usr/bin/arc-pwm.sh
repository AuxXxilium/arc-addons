#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

OUTFILE="/etc/pwm.conf"
STEP=5
DELAY=2

# Stop fancontrol before sweep
/usr/bin/pkill -f "/usr/sbin/fancontrol" 2>/dev/null && rm -f "/run/fancontrol.pid"

echo "# PWM training results: PWM PWM_VALUE FAN FAN_RPM" > "$OUTFILE"

for hw in /sys/class/hwmon/hwmon*; do
  for pwm in "$hw"/pwm*; do
    [ -w "$pwm" ] || continue
    if [ -w "${pwm}_enable" ]; then
      echo 1 > "${pwm}_enable"
    fi
    for fan in "$hw"/fan*_input; do
      [ -r "$fan" ] || continue
      pwm_short="${pwm#/sys/class/hwmon/}"
      fan_short="${fan#/sys/class/hwmon/}"
      echo "Testing $pwm_short with $fan_short"
      old_pwm=$(cat "$pwm")
      for ((val=0; val<=255; val+=STEP)); do
        echo $val > "$pwm"
        sleep $DELAY
        rpm=$(cat "$fan")
        echo "$fan_short $rpm $pwm_short $val" >> "$OUTFILE"
        echo "PWM $val -> FAN $rpm"
      done
      echo $old_pwm > "$pwm"
    done
  done
done

echo "Training complete. Results saved to $OUTFILE"

# Restart fancontrol after training
/usr/bin/arc-sensors.sh >/dev/null 2>&1 &