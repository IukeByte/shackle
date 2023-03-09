#!/bin/bash

# takes a tinycore iso and adds custom packages to it
# written by CVFD
#
# depends:
# - cdrtools (for mkisofs)
# - syslinux (for isohybrid)
# - p7zip (extracting the iso)
# - cpio (for creating the cpio file)
# - squashfs-tools (for extracting the tcz files)

extensions="ntfs-3g util-linux"
origISO="Core-current.iso"

# take use of timeout
sudo true

# extract our iso
7z x $origISO -oisoext

# get extensions
cd extensions
sudo ./FetchExt.sh $extensions
cd ..

# get core.gz for modification
mv isoext/boot/core.gz .

# extract core.gz
mkdir coreext
cd coreext
zcat ../core.gz | sudo cpio -i -H newc -d
cd ..

# extract extensions
cd extensions
for tcztoext in *.tcz; do
    unsquashfs -f $tcztoext
done

# inject extensions to core
sudo cp -r squashfs-root/* ../coreext/

# inject a script to run at login
cd ../coreext/
sudo cp ../startup.sh etc/profile.d/startup.sh

# compile new core.gz
sudo rm ../core.gz
sudo find | sudo cpio -o -H newc | gzip -11 > ../core.gz

# move new core.gz into place
cd ../isoext/
sudo mv ../core.gz boot/core.gz
cd ..

# make our new iso
mkisofs -l -J -R -V sethclinux -no-emul-boot -boot-load-size 4 -boot-info-table -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat -o sethclinux.iso isoext
isohybrid -o 64 sethclinux.iso

# clean up
cd extensions
find . ! -name 'FetchExt.sh' -type f -exec rm -f {} +
rm -r squashfs-root/
cd ..
sudo rm -r isoext/ coreext/