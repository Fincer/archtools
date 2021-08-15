#!/bin/env bash
#
#   pacmankeycheck - Check age of Pacman PGP/GPG public key ring files and update if wanted
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

LIBRARY=${LIBRARY:-'/usr/share/makepkg'}

source "$LIBRARY/util/message.sh"
source "$LIBRARY/util/pkgbuild.sh"

colorize

function keyringcheck() {
  keyfilepath="/etc/pacman.d/gnupg"

  keyfiles=(
    'pubring.gpg'
  #  'secring.gpg'
    'trustdb.gpg'
  )

  # Deadline in days
  deadline=30

  expiredkeys=0
  deadlineseconds=$(($deadline * 24 * 60 * 60))

  for i in ${keyfiles[@]}; do

    file="${keyfilepath}/${i}"
    age=$(( $(date "+%s") - $(stat -c %Z "${file}") ))
    lastupdated=$(date --date=@$(stat -c %Z "${file}"))

    if [[ $age -gt $deadlineseconds ]]; then
      expiredkeys=1
      warning "$(gettext "Pacman PGP/GPG public key ring file %s is over %s days old. Last updated: %s")" "${i}" "${deadline}" "${lastupdated}"
    fi

  done

  if [[ $expiredkeys -eq 1 ]]; then
    msg "$(gettext "Outdated pacman public key ring files may cause issues on package installations.")"
    msg "$(gettext "Do you wish to update the pacman key ring files before proceeding with the pacman command? [Y/n]")"
    read response

    if [[ $(echo $response) =~ ^([yY][eE][sS]|[yY])$ ]]; then
      su root -c 'pacman-key --populate archlinux; pacman-key --refresh'
    fi
  fi
}
