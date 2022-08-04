#!/bin/bash

set -e

KADALU_STORAGE_BRANCH=kadalu_1

# Repo is already checked to a specific
# branch/tag as required.

# Cleanup
rm -rf kadalu-storage-manager-dbgsym_*
rm -rf kadalu-storage-manager-*
rm -rf kadalu-storage-manager_*
rm -rf moana_*
rm -rf python3-kadalu-storage_*
rm -rf moana-*

# Build deb packages
VERSION=${VERSION} make dist
mv moana-${VERSION} kadalu-storage-manager-${VERSION}
rm -rf moana-${VERSION}.tar.gz
tar cvzf kadalu-storage-manager-${VERSION}.tar.gz kadalu-storage-manager-${VERSION}
cp -r packaging/moana/debian kadalu-storage-manager-${VERSION}/

cd kadalu-storage-manager-${VERSION}/
debmake -b":python3"
debuild -eVERSION=${VERSION}
cd ..

# Clone the GlusterFS and checkout Branch
rm -rf kadalu-storage-${VERSION}
git clone https://github.com/kadalu/glusterfs.git kadalu-storage-${VERSION}
cd kadalu-storage-${VERSION}
git checkout -b ${KADALU_STORAGE_BRANCH} origin/${KADALU_STORAGE_BRANCH}
cd ..
tar cvzf kadalu-storage-${VERSION}.tar.gz kadalu-storage-${VERSION}
cp -r packaging/glusterfs/debian kadalu-storage-${VERSION}/

cd kadalu-storage-${VERSION}/
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
