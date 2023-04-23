#!/bin/env sh

#   dummypkg - Create a dummy Arch Linux package
#
#   Copyright (C) 2023  Pekka Helenius <pekka.helenius@fjordtek.com>
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

. /usr/share/makepkg/util/message.sh
colorize

if [[ -z $1 ]]
then
  error "Provide a package name"
  exit 1
fi

PKG=$1
PKGBUILD_FILE="PKGBUILD.tmp"
PACMAN_FILE="pacman.tmp"

msg "Preparing dummy package: $PKG"

description="dummy package"
version="0.1"
release="1"
provides=($PKG)

purge() {

  msg "Cleaning up..."

  pkgfile_prefix="$PKG-$version-$release-any.pkg.tar"
  pkgfile=$(find . -maxdepth 1 -type f -iname "${pkgfile_prefix}*" | head -1)

  [[ -f ${pkgfile} ]] && rm -f ${pkgfile}
  [[ -f ${PKGBUILD_FILE} ]] && rm -f ${PKGBUILD_FILE}
  [[ -f ${PACMAN_FILE} ]] && rm -f ${PACMAN_FILE}
  [[ -d src ]] && rm -rf src
  [[ -d pkg ]] && rm -rf pkg

  exit $1

}

remote_info() {
  pacman_info=$(pacman -Si $PKG > $PACMAN_FILE)
  if [[ $? -eq 0 ]]
  then

    # Description
    description=$(echo $(grep -oP "^Description.*: \K.*(?=.*)" $PACMAN_FILE) "("$description")")

    # Provides
    provides_pkgs=($(grep -oP "^Provides.*: \K[^A-Z]*(?=[^A-Z]*)" $PACMAN_FILE))
    provides=(${provides[@]} ${provides_pkgs[@]})

    # Version
    version_full=$(grep -oP "^Version.*: \K.*(?=.*)" $PACMAN_FILE)
    version=$(echo $version_full | awk '{sub(/-.*/,"",$0); print $0}')
    release=$(echo $version_full | awk '{sub(/.*-/,"",$0); print $0}')

  fi

}

trap "purge 1" SIGINT SIGKILL SIGABRT SIGTERM

msg "Setting version number and provided packages information..."
remote_info

msg2 "Description: ${description}"
msg2 "Provides:    ${provides[*]}"
msg2 "Version:     $version"
msg2 "Release:     $release"

cat <<EOF > ${PKGBUILD_FILE}
pkgname="${PKG}"
pkgver=$version
pkgrel=$release
pkgdesc="${description}"
arch=(any)
provides=(${provides[@]})
groups=(dummy)
EOF

if [[ ! -f ${PKGBUILD_FILE} ]]
then
  error "No PKGBUILD found"
  exit 1
fi

makepkg -Cfi -p ${PKGBUILD_FILE}
purge 0
