#!/bin/bash

# Set variables
ROOT_PATH=$(pwd)
VERSION="7.1"
PLATFORM="apollolake"
EUDEV=true

# Function to deploy environment
deploy_env() {
  echo "Deploying environment..."
  git clone https://github.com/SynologyOpenSource/pkgscripts-ng.git "${ROOT_PATH}/pkgscripts-ng"
  cd "${ROOT_PATH}/pkgscripts-ng"
  git checkout "DSM${VERSION}`[ "${VERSION}" = "6.2" ] && echo ".4"`"
  sudo ./EnvDeploy -v "${VERSION}`[ "${VERSION}" = "6.2" ] && echo ".4"`" -l
  sudo ./EnvDeploy -q -v "$VERSION" -p "$PLATFORM"

  mkdir -p "${ROOT_PATH}/source"
  ENV_PATH="${ROOT_PATH}/build_env/ds.${PLATFORM}-${VERSION}"
  sudo cp -al "${ROOT_PATH}/pkgscripts-ng" "${ENV_PATH}/"

  sudo chroot "${ENV_PATH}" << EOF
cd pkgscripts
version="$VERSION"
[ "\${version:0:1}" -gt 6 ] && sed -i 's/print(" ".join(kernels))/pass #&/' ProjectDepends.py
sed -i '/PLATFORM_FAMILY/a\\techo "PRODUCT=\$PRODUCT" >> \$file\n\techo "KSRC=\$KERNEL_SEARCH_PATH" >> \$file\n\techo "LINUX_SRC=\$KERNEL_SEARCH_PATH" >> \$file' include/build
./SynoBuild -c -p $PLATFORM
EOF
}

# Function to build source
build_source() {
  echo "Building source..."
  mkdir -p "${ROOT_PATH}/source/output"
  sudo cp -a "${ROOT_PATH}/eudev/src" "${ROOT_PATH}/source/input"
  sudo cp -a "${ROOT_PATH}/source" "${ROOT_PATH}/build_env/ds.${PLATFORM}-${VERSION}/"

  sudo chroot "${ROOT_PATH}/build_env/ds.${PLATFORM}-${VERSION}" << EOF
sed -i 's/^CFLAGS=/#CFLAGS=/g; s/^CXXFLAGS=/#CXXFLAGS=/g' /env\${BUILD_ARCH}.mak
while read line; do if [ "\${line:0:1}" != "#" ]; then export "\${line%%=*}"="\${line#*=}"; fi; done < /env\${BUILD_ARCH}.mak

# Build libmount and libblkid
git clone -c http.sslVerify=false --single-branch https://github.com/util-linux/util-linux.git /tmp/util-linux
cd /tmp/util-linux
git checkout v2.42
./autogen.sh
./configure CC=\${CC} CFLAGS='-O2' --prefix=/usr --host=\${HOST} --disable-all-programs --enable-libmount --enable-libblkid --enable-eject
make
make DESTDIR=/source/output install

# Build kmod
git clone -c http.sslVerify=false --single-branch https://github.com/kmod-project/kmod.git /tmp/kmod
cd /tmp/kmod
git checkout v30
patch -p1 < /source/input/kmod.patch 2>/dev/null || true
./autogen.sh
./configure CC=\${CC} CFLAGS='-O2' --prefix=/usr --host=\${HOST} --sysconfdir=/etc --libdir=/lib --enable-tools --disable-manpages --disable-python --without-openssl
[ -z "\$(grep 'env.mak' Makefile)" ] && sed -i '1 i include /env.mak' Makefile
make all
make DESTDIR=/source/output install

# Build eudev
git clone -c http.sslVerify=false --single-branch https://github.com/systemd/systemd.git /tmp/systemd
git clone -c http.sslVerify=false --single-branch https://github.com/eudev-project/eudev.git /tmp/eudev
cd /tmp/eudev
git checkout master

cp -vf /tmp/systemd/hwdb.d/*.ids /tmp/systemd/hwdb.d/*.hwdb hwdb/
./autogen.sh
./configure CC=\${CC} CFLAGS='-O2' --prefix=/usr --host=\${HOST} --sysconfdir=/etc --disable-manpages --disable-selinux --disable-mtd_probe --enable-kmod
[ -z "\$(grep 'env.mak' Makefile)" ] && sed -i '1 i include /env.mak' Makefile
make -i CFLAGS="-DSG_FLAG_LUN_INHIBIT=2" all
make -i CFLAGS="-DSG_FLAG_LUN_INHIBIT=2" DESTDIR=/source/output install

# Copy additional files
cp -rf /source/input/rules.d/* /source/output/usr/lib/udev/rules.d/
cp -rf /source/input/script/* /source/output/usr/lib/udev/script/
mv -f /source/output/usr/lib/udev/rules.d/60-persistent-storage.rules /source/output/usr/lib/udev/rules.d/60-persistent-storage.rules.bak
mv -f /source/output/usr/lib/udev/rules.d/60-persistent-storage-tape.rules /source/output/usr/lib/udev/rules.d/60-persistent-storage-tape.rules.bak
mv -f /source/output/usr/lib/udev/rules.d/80-net-name-slot.rules /source/output/usr/lib/udev/rules.d/80-net-name-slot.rules.bak

# Clean up unnecessary files
rm -rf /source/output/usr/share /source/output/usr/include /source/output/usr/lib/pkgconfig 
rm -f /source/output/usr/sbin/udevadm /source/output/usr/lib/lib*.a /source/output/usr/lib/lib*.la

# Recreate symlinks after cleanup
cp -rf /source/output/usr/* /source/output/
rm -rf /source/output/usr
ln -sf /usr/bin/kmod /source/output/sbin/depmod
ln -sf /usr/bin/kmod /source/output/sbin/modinfo
ln -sf /usr/bin/kmod /source/output/sbin/modprobe
chown 1000.1000 -R /source/output
EOF
}

# Function to package artifacts
package_artifacts() {
  echo "Packaging artifacts..."
  tar caf "${ROOT_PATH}/source/eudev-${VERSION}.tgz" -C "${ROOT_PATH}/source/output/" .
}

# Main script execution
if $EUDEV; then
  deploy_env
  build_source
  package_artifacts
fi