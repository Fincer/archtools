#!/usr/bin/env bash
#
#   showpkg - Show specific package version - installed and available version
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

echo ""
PACMAN_EXEC="/usr/bin/pacman"

for p in $(echo "${@}"); do

    INSTALLDATE=$(${PACMAN_EXEC} -Qi $p | grep "Install Date" | awk -F ': ' '{print $2}')
    NEWDATE=$(${PACMAN_EXEC} -Si $p | grep "Build Date" | awk -F ': ' '{print $2}')
    echo "Installed: $(${PACMAN_EXEC} -Q $p) ($INSTALLDATE)"
    echo $(${PACMAN_EXEC} -Si $p | grep -E "Version.*:|Build Date.*:" | awk -F ': ' '{print $2}') | awk -v pkg=$p -F ' ' '{print "Available: " pkg " " $1 " ("substr($0,length($1)+1)")"}' | sed 's/( /(/g'
    echo ""
    #echo -e "Available: $p $($PKGMGR -Si $p | grep "Version.*:" | awk -F ' ' '{print $3}')\n"
done
