#!/usr/bin/env bash
#
#   buildpkg - Build a local package on the current directory which has PKGBUILD on Arch Linux
#
#   Copyright (C) 2021  Pekka Helenius <pekka.helenius@fjordtek.com>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.

#####################################

# Requires package: pacman-contrib

if [ ! -e ./PKGBUILD ]; then #We check whether PKGBUILD file exists. If no, then...
    echo -e "No PKGBUILD file found!\n"
    return 1
else
    rm -Rf ./{src,pkg} #This doesn't mean they really exist
    updpkgsums
    makepkg -f
fi
