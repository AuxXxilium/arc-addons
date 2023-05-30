#!/usr/bin/env ash

if [ "${1}" = "early" ]; then
  /usr/bin/cpufreqscaling.sh 2>/dev/null
elif [ "${1}" = "late" ]; then
  echo "Creating service to exec CPU Freq Scaling"
  cp -vf /usr/bin/cpufreqscaling.sh /tmpRoot/usr/bin/cpufreqscaling.sh
  DEST="/tmpRoot/lib/systemd/system/cpufreqscaling.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=Enable CPU Freq Scaling"                                  >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "User=root"                                                            >>${DEST}
  echo "Restart=on-abnormal"                                                  >>${DEST}
  echo "Environment=lowload=150"                                              >>${DEST}
  echo "Environment=midload=250"                                              >>${DEST}
  echo "ExecStart=/usr/bin/cpufreqscaling.sh"                                 >>${DEST}
  echo "ExecStop=/usr/bin/cpufreqscaling.sh"                                  >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -p /tmpRoot/etc/systemd/system/multi-user.target.wants
  ln -sf /lib/systemd/system/cpufreqscaling.service /tmpRoot/lib/systemd/system/multi-user.target.wants/cpufreqscaling.service
fi