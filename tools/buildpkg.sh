#!/bin/bash

#############################
# Build local package in PKGBUILD directory on Arch Linux
#
if [ ! -e ./PKGBUILD ]; then #We check whether PKGBUILD file exists. If no, then...
    echo -e "No PKGBUILD file found!\n"
    return 1
else
    rm -Rf ./{src,pkg} #This doesn't mean they really exist
    updpkgsums
    makepkg -f
fi
