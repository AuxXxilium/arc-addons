#!/bin/bash
#
# Runs inside auxxxilium/syno-compiler via:
#   docker run -v $(pwd)/eudev/src:/input -v $(pwd)/output:/output \
#     auxxxilium/syno-compiler:<dsm-version> compile-binary <platform> build.sh
#
# PLATFORM and ROOT_PATH are exported by the container entrypoint.
#
# Unlike compile-module/compile-lkm/shell, the compile-binary entrypoint does
# NOT call export-vars — so CC/CROSS_COMPILE/KSRC/etc. are not set for us
# here. We source /opt/do.sh (the entrypoint script) and call export-vars
# ourselves so eudev/kmod link against the correct platform toolchain and
# build against the correct kernel headers instead of the container's
# native host gcc/glibc.
#
# EXPECTED_KVER (optional): if set, asserts it matches the kver the toolkit
# image has baked in for PLATFORM (from /opt/platforms), so a mismatch
# between the build matrix and the toolkit image fails fast instead of
# silently producing a binary for the wrong kernel branch.

set -e

HOST="x86_64-pc-linux-gnu"
OUT="${ROOT_PATH}/output"
SYSROOT="/opt/${PLATFORM}/${HOST}/sys-root"

mkdir -p "${OUT}"

KVER="$(awk -v p="${PLATFORM}" '$1 == p { print $2 }' /opt/platforms)"
if [ -z "${KVER}" ]; then
  echo "[ERROR] No kver found for platform ${PLATFORM} in /opt/platforms"
  exit 1
fi
if [ -n "${EXPECTED_KVER:-}" ] && [ "${KVER}" != "${EXPECTED_KVER}" ]; then
  echo "[ERROR] kver mismatch for ${PLATFORM}: toolkit has ${KVER}, expected ${EXPECTED_KVER}"
  exit 1
fi
export KVER
echo "Building for platform=${PLATFORM} kver=${KVER}"

# /opt/do.sh ends with a command dispatcher that would exit immediately if we
# sourced it directly (no matching subcommand for build.sh's own args), so
# only source its function definitions (everything before that dispatcher).
# shellcheck disable=SC1090,SC1091
source <(sed -n '1,/^if \[ \$# -lt 1 \]/p' /opt/do.sh | sed '$d')
export-vars "${PLATFORM}"

# export-vars only writes /etc/profile.d/path.sh (sourced by login shells);
# compile-binary runs this script non-interactively, so PATH is not updated
# automatically — prepend the toolchain bin dir ourselves.
export PATH="/opt/${PLATFORM}/bin:${PATH}"

command -v "${CC}" >/dev/null 2>&1 || { echo "[ERROR] ${CC} not found on PATH"; exit 1; }

# Build libmount and libblkid
git clone -c http.sslVerify=false --single-branch --branch v2.42 https://github.com/util-linux/util-linux.git /tmp/util-linux
cd /tmp/util-linux
./autogen.sh
# The DSM sysroot's linux/mount.h unconditionally redeclares enum
# fsconfig_command / struct mount_attr, which glibc >= 2.36's sys/mount.h
# (gcc1220_glibc236 toolchain) already provides, causing a build failure
# regardless of --disable-libmount-mountfd-support (that flag only gates
# use of the FD-based mount API, not the AC_CHECK_HEADERS([linux/mount.h])
# probe that triggers the include). Hide the conflicting kernel header from
# the include path so configure falls back to sys/mount.h's definitions.
SYSROOT_MOUNT_H="${SYSROOT}/usr/include/linux/mount.h"
[ -f "${SYSROOT_MOUNT_H}" ] && sudo mv -f "${SYSROOT_MOUNT_H}" "${SYSROOT_MOUNT_H}.bak"

# This sysroot's scsi/sg.h declares sg_io_hdr_t.sbp as void*, but eject.c
# indexes it directly (io_hdr.sbp[2], io_hdr.sbp[12]), which is invalid on
# void* under strict C rules. Cast to unsigned char* at both use sites.
sed -i 's/io_hdr\.sbp\[/((unsigned char *)io_hdr.sbp)[/g' sys-utils/eject.c

./configure CC="${CC}" CFLAGS='-O2' --prefix=/usr --host="${HOST}" --disable-all-programs --enable-libmount --enable-libblkid --enable-eject --disable-libmount-mountfd-support
make
make DESTDIR="${OUT}" install
# eudev's ./configure below runs PKG_CHECK_MODULES([BLKID], ...) against the
# cross toolchain's own sysroot, not ${OUT} — install the just-built
# libblkid headers/.pc/.so there too so eudev can find and link against it.
sudo env PATH="${PATH}" make DESTDIR="${SYSROOT}" install

# Build kmod
git clone -c http.sslVerify=false --single-branch --branch v30 https://github.com/kmod-project/kmod.git /tmp/kmod
cd /tmp/kmod
patch -p1 < "${ROOT_PATH}/kmod.patch" 2>/dev/null || true
./autogen.sh
./configure CC="${CC}" CFLAGS='-O2' --prefix=/usr --host="${HOST}" --sysconfdir=/etc --libdir=/lib --enable-tools --disable-manpages --disable-python --without-openssl
make all
make DESTDIR="${OUT}" install
# Same as libblkid above: eudev's PKG_CHECK_EXISTS([libkmod]) needs to find
# this in the cross toolchain's sysroot, not just in ${OUT}.
sudo env PATH="${PATH}" make DESTDIR="${SYSROOT}" install

# Build eudev
git clone -c http.sslVerify=false --single-branch https://github.com/systemd/systemd.git /tmp/systemd
git clone -c http.sslVerify=false --single-branch --branch master https://github.com/eudev-project/eudev.git /tmp/eudev
cd /tmp/eudev

cp -vf /tmp/systemd/hwdb.d/*.ids /tmp/systemd/hwdb.d/*.hwdb hwdb/

# autogen.sh unconditionally runs man/make.sh after autoreconf, which invokes
# xsltproc against custom-man.xsl's <xsl:import> of the Docbook XSL
# stylesheets from docbook.sourceforge.net. The build container has no
# network access and no local Docbook XSL catalog, so this always fails —
# independent of --disable-manpages below, which only skips *installing*
# man pages, not autogen's attempt to generate them. Stub out man/make.sh
# so autoreconf's man page generation step is a no-op.
echo '#!/bin/sh' > man/make.sh
./autogen.sh

# util-linux (libblkid) and kmod were also installed into ${SYSROOT} above,
# so their .pc files live under ${SYSROOT}/usr/lib/pkgconfig and
# ${SYSROOT}/lib/pkgconfig (kmod's ./configure used --libdir=/lib). Point
# pkg-config at them so eudev's PKG_CHECK_MODULES([BLKID]) /
# PKG_CHECK_EXISTS([libkmod]) succeed, and clear PKG_CONFIG_LIBDIR-inherited
# host search paths so we don't accidentally link against the container's
# native libs instead of the cross-built ones.
export PKG_CONFIG_PATH="${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="${PKG_CONFIG_PATH}"

./configure CC="${CC}" CFLAGS='-O2' --prefix=/usr --host="${HOST}" --sysconfdir=/etc --disable-manpages --disable-selinux --disable-mtd_probe --enable-kmod
make -i CFLAGS="-DSG_FLAG_LUN_INHIBIT=2" all
make -i CFLAGS="-DSG_FLAG_LUN_INHIBIT=2" DESTDIR="${OUT}" install

# Copy additional files
cp -rf "${ROOT_PATH}/rules.d/"* "${OUT}/usr/lib/udev/rules.d/"
mkdir -p "${OUT}/usr/lib/udev/script"
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
