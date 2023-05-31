#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Creating service to exec CPU Freq Scaling"
  cp -vf /usr/sbin/cpufreqscaling.sh /tmpRoot/usr/sbin/cpufreqscaling.sh
  chmod 755 /tmpRoot/usr/sbin/cpufreqscaling.sh

  DEST="/tmpRoot/lib/systemd/system/cpufreqscaling.service"
  echo "[Unit]"                                                                >${DEST}
  echo "Description=Enable CPU Freq Scaling"                                  >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Service]"                                                            >>${DEST}
  echo "User=root"                                                            >>${DEST}
  echo "Restart=on-abnormal"                                                  >>${DEST}
  echo "Environment=lowload=150"                                              >>${DEST}
  echo "Environment=midload=250"                                              >>${DEST}
  echo "ExecStart=/usr/sbin/cpufreqscaling.sh"                                >>${DEST}
  echo                                                                        >>${DEST}
  echo "[Install]"                                                            >>${DEST}
  echo "WantedBy=multi-user.target"                                           >>${DEST}

  mkdir -p /tmpRoot/lib/systemd/system/multi-user.target.wants
  ln -sf /lib/systemd/system/cpufreqscaling.service /tmpRoot/lib/systemd/system/multi-user.target.wants/cpufreqscaling.service
fi