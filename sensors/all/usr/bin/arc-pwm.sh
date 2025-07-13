#!/usr/bin/env bash
#
# Copyright (C) 2025 AuxXxilium
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

OUTFILE="/etc/pwm.conf"
STEP=5
DELAY=3
MAX=255

# Stop fancontrol before sweep
/usr/bin/pkill -f "/usr/sbin/fancontrol" 2>/dev/null && rm -f "/run/fancontrol.pid"

echo "# PWM training results: PWM PWM_VALUE FAN FAN_RPM" > "$OUTFILE"

for hw in /sys/class/hwmon/hwmon*; do
  for pwm in "$hw"/pwm[0-9]*; do
    [ -w "$pwm" ] || continue
    pwm_num=$(basename "$pwm" | sed 's/pwm\([0-9]\+\).*/\1/')
    [ -r "${pwm}_enable" ] || continue
    # Set PWM mode to manual before test
    if [ -w "${pwm}_enable" ]; then
      old_pwm_enable=$(cat "${pwm}_enable")
      echo 1 > "${pwm}_enable"
    fi
    for fan in "$hw"/fan*_input; do
      [ -r "$fan" ] || continue
      fan_num=$(basename "$fan" | sed 's/fan\([0-9]\+\)_input.*/\1/')
      [ "$pwm_num" = "$fan_num" ] || continue
      rpm_test=$(cat "$fan")
      if [ "$rpm_test" = "0" ] || [ "$rpm_test" = "-1" ]; then
        continue
      fi
      pwm_short="${pwm#/sys/class/hwmon/}"
      fan_short="${fan#/sys/class/hwmon/}"
      echo "Testing $pwm_short with $fan_short"
      old_pwm=$(cat "$pwm")
      sleep $DELAY
      for ((val=0; val<=MAX; val+=STEP)); do
        echo $val > "$pwm"
        sleep $DELAY
        rpm=$(cat "$fan")
        echo "PWM $val -> FAN $rpm"
        if [ $val -ge 30 ]; then
          echo "$fan_short $rpm $pwm_short $val" >> "$OUTFILE"
        fi
      done
      echo $old_pwm > "$pwm"
    done
    # Restore PWM mode to previous value after test
    if [ -w "${pwm}_enable" ]; then
      echo "$old_pwm_enable" > "${pwm}_enable"
    fi
  done
done

echo "Training complete. Results saved to $OUTFILE"

# Restart fancontrol after training
/usr/bin/arc-sensors.sh >/dev/null 2>&1 &