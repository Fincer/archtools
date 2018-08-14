#!/bin/bash

################################
# Remove build-time files after program compilation on Arch Linux
#
if [ ! -e ./PKGBUILD ] && [ ! -d ./{src,pkg} ]; then #We check whether PKGBUILD file and src,pkg directories exist. If no, then...
    echo -e "Nothing to be removed\n"
    exit
else
    rm -Rf ./{src,pkg,packages,community,*tar.xz} #tar.xz file may or may not exist
fi
