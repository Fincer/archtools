#!/usr/bin/env sh
#
#   whichcmd - Find available commands in PATH by input syntax
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

if [[ ${1} == "-h" ]] || [[ ${1} == "--help" ]] || [[ -z ${1} ]]; then
  echo "
Find available commands in PATH by input syntax.
Usage: $(basename $0) <command syntax>
"
  exit 0
fi

PATHS=($(echo "${PATH}" | sed 's/:/ /g') )

for p in ${PATHS[@]}; do
  find "${p}" -iname "*${1}*"
done
