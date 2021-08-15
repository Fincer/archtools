#!/usr/bin/env bash
#
#   findmatch - Grep/List matching strings in a specific folder
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

if [ -z "$1" ]; then
    $1=/ #If folder not specified, then we use root folder as a starting path
fi

if [ -z "$2" ]; then #If string not defined, then...
    # display usage if no string is given
    echo "Usage: findmatch <folder_path> <string>"
    return 1
else
    ls $1 |grep -i "$2"
fi
