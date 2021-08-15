#!/usr/bin/env bash
#
#   pkginfo - Gather package information with pacman on Arch Linux
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

FILETHRESHOLD=100
PACMAN_EXEC="/usr/bin/pacman"

if [[ $2 == "local" ]]; then
    ${PACMAN_EXEC} -Qi $1
    if [[ $3 == "files" ]]; then
        if [[ $(${PACMAN_EXEC} -Qql $1 | wc -l) -gt $FILETHRESHOLD ]]; then
            echo "Package $1 has $(pacman -Qql $1 | wc -l) files/dirs"
            sleep 3
            ${PACMAN_EXEC} -Qql $1 | less
        fi
    fi
elif [[ $2 == "remote" ]]; then
    ${PACMAN_EXEC} -Si $1
    if [[ $3 == "files" ]]; then
        if [[ $(${PACMAN_EXEC} -Qql $1 | wc -l) -gt $FILETHRESHOLD ]]; then
            echo "Package $1 has $(pacman -Qql $1 | wc -l) files/dirs"
            sleep 3
            ${PACMAN_EXEC} -Qql $1 | less
        fi
    fi
else
    echo -e "Input: sh pkginfo.sh <package> [local/remote] [optional arg:files]\n"
fi
