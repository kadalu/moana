#!/bin/bash

KADALU_STORAGE_BRANCH=kadalu_1

# Repo is already checked to a specific
# branch/tag as required.

# Cleanup
rm -rf kadalu-storage-manager-dbgsym_*
rm -rf kadalu-storage-manager_*
rm -rf moana_*
rm -rf python3-kadalu-storage_*
rm -rf moana-*

# Build deb packages
VERSION=${VERSION} make dist
cp -r packaging/moana/debian moana-${VERSION}/

cd moana-${VERSION}/
debmake -b":python3"
debuild -eVERSION=${VERSION}
cd ..

# Clone the GlusterFS and checkout Branch
git clone https://github.com/kadalu/glusterfs.git glusterfs-${VERSION}
cd glusterfs-${VERSION}
git checkout -b ${KADALU_STORAGE_BRANCH} origin/${KADALU_STORAGE_BRANCH}
cd ..
tar cvzf glusterfs-${VERSION}.tar.gz glusterfs-${VERSION}
cp -r packaging/glusterfs/debian glusterfs-${VERSION}/

cd glusterfs-${VERSION}/
debmake -b":python3"
debuild
cd ..

rm -rf build
mkdir -p build
cp *.deb build/

# List of packages
cd build
dpkg-scanpackages --multiversion . > Packages
gzip -k -f Packages

# Import the Signing key from env var
echo -n "$PACKAGING_GPG_SIGNING_KEY" | base64 --decode | gpg --import

# Release, Release.gpg & InRelease
apt-ftparchive release . > Release
gpg --default-key "packaging@kadalu.tech" -abs -o - Release > Release.gpg
gpg --default-key "packaging@kadalu.tech" --clearsign -o - Release > InRelease
gpg --armor --export "packaging@kadalu.tech" > KEY.gpg

echo "deb https://github.com/kadalu/moana/releases/latest/download ./" > kadalu_storage.list
cd ..
