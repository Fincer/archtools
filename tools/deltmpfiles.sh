#!/usr/bin/env bash
#
#   deltmpfiles - Delete current temporary files from pre-defined locations
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

#All tmp files currently being used
TMP_USED=$(lsof +D /tmp/ | awk '{print $9," "}' | sort -u | tail -n+3 | sed 's/[ \t]*$//')

#All tmp files
TMP_ALL=$(find /tmp/ -type s -print -o -type f -print | sort -u | sed 's/[ \t]*$//')

#Get all tmp files/symlinks/etc which are not being used at the moment
# Exclude /tmp/.X11-unix/X0 from the list
#
TMP_NOTUSED=$(comm -23 <(echo "$TMP_ALL") <(echo "$TMP_USED") | sed 's/\/tmp\/.X11-unix\/X0//g; /^\s*$/d')

echo "$TMP_NOTUSED" | while read line; do echo "Deleting file $line" && sudo rm $line ; done
