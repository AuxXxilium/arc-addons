#!/bin/bash
#
# Runs inside auxxxilium/syno-compiler via:
#   docker run -v $(pwd)/eudev/src:/input -v $(pwd)/output:/output \
#     auxxxilium/syno-compiler:<dsm-version> compile-binary <platform> build.sh
#
# PLATFORM and ROOT_PATH are exported by the container entrypoint.
# CC, LD, CROSS_COMPILE, KSRC, CFLAGS, LDFLAGS, LD_LIBRARY_PATH, ARCH are
# exported by export-vars for the selected platform.

set -e

HOST="x86_64-pc-linux-gnu"
OUT="${ROOT_PATH}/output"

mkdir -p "${OUT}"

# Build libmount and libblkid
git clone -c http.sslVerify=false --single-branch https://github.com/util-linux/util-linux.git /tmp/util-linux
cd /tmp/util-linux
git checkout v2.42
./autogen.sh
./configure CC="${CC}" CFLAGS='-O2' --prefix=/usr --host="${HOST}" --disable-all-programs --enable-libmount --enable-libblkid --enable-eject
make
make DESTDIR="${OUT}" install

# Build kmod
git clone -c http.sslVerify=false --single-branch https://github.com/kmod-project/kmod.git /tmp/kmod
cd /tmp/kmod
git checkout v30
patch -p1 < "${ROOT_PATH}/kmod.patch" 2>/dev/null || true
./autogen.sh
./configure CC="${CC}" CFLAGS='-O2' --prefix=/usr --host="${HOST}" --sysconfdir=/etc --libdir=/lib --enable-tools --disable-manpages --disable-python --without-openssl
make all
make DESTDIR="${OUT}" install

# Build eudev
git clone -c http.sslVerify=false --single-branch https://github.com/systemd/systemd.git /tmp/systemd
git clone -c http.sslVerify=false --single-branch https://github.com/eudev-project/eudev.git /tmp/eudev
cd /tmp/eudev
git checkout master

cp -vf /tmp/systemd/hwdb.d/*.ids /tmp/systemd/hwdb.d/*.hwdb hwdb/
./autogen.sh
./configure CC="${CC}" CFLAGS='-O2' --prefix=/usr --host="${HOST}" --sysconfdir=/etc --disable-manpages --disable-selinux --disable-mtd_probe --enable-kmod
make -i CFLAGS="-DSG_FLAG_LUN_INHIBIT=2" all
make -i CFLAGS="-DSG_FLAG_LUN_INHIBIT=2" DESTDIR="${OUT}" install

# Copy additional files
cp -rf "${ROOT_PATH}/rules.d/"* "${OUT}/usr/lib/udev/rules.d/"
cp -rf "${ROOT_PATH}/script/"* "${OUT}/usr/lib/udev/script/"
mv -f "${OUT}/usr/lib/udev/rules.d/60-persistent-storage.rules" "${OUT}/usr/lib/udev/rules.d/60-persistent-storage.rules.bak"
mv -f "${OUT}/usr/lib/udev/rules.d/60-persistent-storage-tape.rules" "${OUT}/usr/lib/udev/rules.d/60-persistent-storage-tape.rules.bak"
mv -f "${OUT}/usr/lib/udev/rules.d/80-net-name-slot.rules" "${OUT}/usr/lib/udev/rules.d/80-net-name-slot.rules.bak"

# Clean up unnecessary files
rm -rf "${OUT}/usr/share" "${OUT}/usr/include" "${OUT}/usr/lib/pkgconfig"
rm -f "${OUT}/usr/sbin/udevadm" "${OUT}/usr/lib"/lib*.a "${OUT}/usr/lib"/lib*.la

# Recreate symlinks after cleanup
cp -rf "${OUT}/usr/"* "${OUT}/"
rm -rf "${OUT}/usr"
