#!/bin/bash

##############################################
# Install locally build program on Arch Linux

if [ -e ./PKGBUILD ]; then #We check whether PKGBUILD file exists. If yes, then...
    PACKAGE_NAME=$(cat ./PKGBUILD | grep "pkgname=" | sed -e 's/pkgname=//g') #get package name from PKGBUILD
    PACKAGE=$(echo $PACKAGE_NAME*.pkg.tar.xz) #package name + * + suffix

    if [ -e $PACKAGE ]; then # If package has been compiled, then...
        sudo pacman -U $PACKAGE # ...install the package.
    fi
else
    return 1
fi
