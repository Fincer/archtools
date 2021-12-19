#!/usr/bin/env bash
#
#   getsource - Get build files from Arch Linux official, AUR & ARM repositories
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
#
# TODO: Add support for wider range of processor architectures
# TODO: Add directory support (e.g. getsource wine ~/winesource)
# TODO: create subdir for source files automatically to the current main dir

LIBRARY=${LIBRARY:-'/usr/share/makepkg'}

source "$LIBRARY/util/message.sh"

# check if messages are to be printed using color
if [[ -t 2 && $USE_COLOR != "n" ]]; then
    colorize
else
    unset ALL_OFF BOLD BLUE GREEN RED YELLOW
fi

PACKAGE=$(pwd | awk '{print $NF}' FS=/)

if [[ -n "$1" ]]; then
    PACKAGE="$1"
else
    read -r -p "Source package name? [Default: $PACKAGE ] " response
    if [[ -n $response ]]; then
        PACKAGE=$response
    else
      echo "Assuming current dir name [ $PACKAGE ]"
    fi
fi

INPUT="${CURDIR}"

BUILDSCRIPT="PKGBUILD"
URLFILE="baseurl.html"

ARCHIVEFORMATS=(
  'tar.gz'
  'tar.xz'
  'tar.lz'
  'tar.zst'
)

##################################

DBS_TO_CHECK=('arch' 'aur' 'arm' 'arch_deepscan')

ARCH_DATABASES=(
  'core'
  'extra'
  'community'
  'community-testing'
)

ARM_DATABASES=(
  'alarm'
  'aur'
  'community'
  'core'
  'extra'
)

# TODO
# Fetch from pacman.conf
CUSTOM_DATABASES=()

ARCH_GITBASES=(
  'archlinux/svntogit-packages'
  'archlinux/svntogit-community'
)

ARM_GITBASES=(
  'archlinuxarm/PKGBUILDs'
)

##################################

function get_url() {
  if ! wget --no-check-certificate -q -T 10 "${1}" -O - >/dev/null; then return 1; fi
  if wget --no-check-certificate -q -c "${1}" -O "${2}"; then return 0; fi
  return 1
}

##################################

function fetch_database() {

  case "${1}" in
    #custom) TODO
      #BASEURL="<get-from-pacman.conf"
      # Doesn't need separate DOMAINURL/BASEURL schema

      #get_url archive "${BASEURL}" && \
      #tar xf "$PACKAGE.${ARCHIVEFORMAT}" && \
      #break
      #;;
    arch)
      GITBASES=(${ARCH_GITBASES[@]})
      DOMAINURL="https://github.com"
      REPOMSG="Using Arch Linux official repositories"

      for GITBASE in ${GITBASES[@]}; do
        BASEURL="${DOMAINURL}/${GITBASE}/tree/packages/${PACKAGE}/trunk"

        if get_url "${BASEURL}" "${URLFILE}"; then
          FILENAMES=()

          FILEHREFS=( $(grep -oP '(?<=data-pjax).*?(?=\<\/a)' "${URLFILE}" | sed -r "s/.*href=[\"|'](.*)[\"|']>.*/\1/; s/\/blob//g" | grep trunk) )
          for i in ${FILEHREFS[@]}; do
            FILENAMES+=( $(echo "${i}" | sed 's/.*\///g') )
          done
          DOMAINURL="https://raw.githubusercontent.com"
          download_sourcefiles && return 0
        fi
      done
      return 1
      ;;

    aur)
      local ISSNAPSHOT
      DOMAINURL="https://aur.archlinux.org"
      local SNAPSHOTURL="${DOMAINURL}/packages/${PACKAGE}/"
      REPOMSG="Using Arch Linux user repositories (AUR)"

      if get_url "${SNAPSHOTURL}" "${URLFILE}"; then
        FILEHREFS=($(grep -oP '(?<=href\=\"\/).*?(?=\"\>Download snapshot)' "${URLFILE}"))
        FILENAMES=($(grep -oP '(?<=snapshot\/).*?(?=\"\>Download snapshot)' "${URLFILE}"))
        download_sourcefiles && return 0
      fi
      return 1
      ;;

    arm)
      GITBASES=(${ARM_GITBASES[@]})
      DATABASES=(${ARM_DATABASES[@]})
      DOMAINURL="https://github.com"
      REPOMSG="Using Arch Linux ARM repositories"

      for GITBASE in ${GITBASES[@]}; do
        for DATABASE in ${DATABASES[@]}; do
          BASEURL="${DOMAINURL}/${GITBASE}/tree/master/${DATABASE}/${PACKAGE}"

          if get_url "${BASEURL}" "${URLFILE}"; then
            FILENAMES=()

            FILEHREFS=( $(grep -oP '(?<=data-pjax).*?(?=\<\/a)' "${URLFILE}" | sed -r "s/.*href=[\"|'](.*)[\"|']>.*/\1/; s/\/blob//g" | grep ${PACKAGE}) )
            for i in ${FILEHREFS[@]}; do
              FILENAMES+=( $(echo "${i}" | sed 's/.*\///g') )
            done
            DOMAINURL="https://raw.githubusercontent.com"
            download_sourcefiles && return 0
          fi
        done
      done
      return 1
      ;;

    arch_deepscan)
      arch_repos_deepscan
      ;;

  esac

  [[ -f "${URLFILE}" ]] || return 1

}

##################################

function arch_repos_deepscan() {

  for ARCH_DB in ${ARCH_DATABASES[@]}; do
    ARCH_DB_URL="https://www.archlinux.org/packages/${ARCH_DB}/x86_64/${PACKAGE}"
    get_url "${ARCH_DB_URL}" "${URLFILE}"
  done

  if [[ -f "${URLFILE}" ]]; then
    msg "$(gettext "Selecting another package name:")"
    PACKAGE=$(grep "Source Files" "${URLFILE}" | sed "s/.*href=[\"'].*packages\///g; s/[\"'].*//g")
    warning "$(gettext "Package name is %s")" "${PACKAGE}"
    rm -rf "${URLFILE}"
    fetch_database arch ${ARCH_GITBASES[@]}
    download_sourcefiles
  else
    error "$(gettext "Couldn't find package %s")" "${PACKAGE}"
    exit 1
  fi

}

##################################

function download_sourcefiles() {

  if [[ -f "${URLFILE}" ]]; then

    msg "${REPOMSG}"

    local a=0
    for FILEURL in ${FILEHREFS[@]}; do

      echo "${DOMAINURL}/${FILEURL} ${FILENAMES[$a]}"
      msg2 "$(gettext "Downloading %s...")" "${FILENAMES[$a]}"
      $(wget -q "${DOMAINURL}/${FILEURL}" -O "${FILENAMES[$a]}")

      [[ -f "${FILENAMES[$a]}" ]] || warning "$(gettext "Couldn't download %s")" "${FILENAMES[$a]}"
      let a++
    done

    rm -rf "${URLFILE}"

    if [[ ISSNAPSHOT ]]; then
      for ARCHIVEFORMAT in "${ARCHIVEFORMATS[@]}"; do
        find . -iname "*${ARCHIVEFORMAT}" -exec tar xf {} --strip-components=1 \;
      done
    fi

    if [[ $? -eq 0 ]]; then
      msg "$(gettext "Source files for %s downloaded")" "${PACKAGE}"
      return 0
    fi

  fi

}

##################################

# TODO
#<if any custom databases configured in pacman.conf>
#DBS_TO_CHECK+=('custom')

for db in ${DBS_TO_CHECK[@]}; do
  [[ $(fetch_database "${db}") ]] && break
done

##################################

if [[ -f ${BUILDSCRIPT} ]]; then
  sed -i "s/^arch=.*/arch=('any')/" ${BUILDSCRIPT}
  if [[ $? -eq 0 ]]; then msg "$(gettext "Set architecture to 'any' in ${BUILDSCRIPT}.")"; fi
fi
