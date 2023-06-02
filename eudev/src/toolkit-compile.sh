#!/usr/bin/env bash

rm -rf /source
git clone -c http.sslVerify=false --single-branch https://github.com/kmod-project/kmod.git /tmp/kmod
cd /tmp/kmod
git checkout master
patch -p1 < /home/auxxxilium/arc-addons/eudev/src/kmod.patch
./autogen.sh
./configure CFLAGS='-O2' --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib --enable-tools --disable-manpages --disable-python --without-zstd --without-xz --without-zlib --without-openssl
make all
make install
make DESTDIR=/home/auxxxilium/arc-addons/eudev/all install
git clone -c http.sslVerify=false --single-branch https://github.com/eudev-project/eudev.git /tmp/eudev
cd /tmp/eudev
git checkout master
./autogen.sh
./configure --prefix=/usr --sysconfdir=/etc --disable-manpages --disable-selinux --disable-mtd_probe --enable-kmod
make -i all
make -i DESTDIR=/home/auxxxilium/arc-addons/eudev/all install
rm -Rf /home/auxxxilium/arc-addons/eudev/all/usr/share /home/auxxxilium/arc-addons/eudev/all/usr/include /home/auxxxilium/arc-addons/eudev/all/usr/lib/pkgconfig /home/auxxxilium/arc-addons/eudev/all/usr/lib/libudev.*
rm /home/auxxxilium/arc-addons/eudev/all/usr/lib/udev/rules.d/80-net-name-slot.rules
ln -sf /usr/bin/kmod /home/auxxxilium/arc-addons/eudev/all/usr/sbin/depmod
chown 1000.1000 -R /home/auxxxilium/arc-addons/eudev/all