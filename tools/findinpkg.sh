#!/usr/bin/env bash
#
#   findinpkg - Find text patterns & print occurences with matching lines numbers in Arch Linux package files
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

function help() {
  echo -e "Usage: findinpkg <pkgname> <pattern-to-search>"
  exit
}

if [[ ${#@} -ne 2 ]]; then
  help
fi

if [[ ! $(pacman -Qq "${1}" 2> /dev/null) ]]; then
  echo "Can't find package ${1}"
  help
fi

filematches=()
lines_total=0
files_total=0
typeset -A FILEMATCHES
esc=$(printf '\033')

for file in $(pacman -Qlq "${1}"); do
  if [[ -f "${file}" ]]; then

    filestr=$(grep --line-number --with-filename --binary-files=without-match -i "${2}" "${file}" | sed -r "s/^(.*?:)([0-9]+):.*/\1\2/g")

    # In some rare cases grepped files are presented on the same line
    for filestr in ${filestr[@]}; do
      filematches+=(${filestr})
    done

  fi
done

for filematch in ${filematches[@]}; do
  filename_=$(printf '%s' "${filematch}" | sed -r 's/^(.*?):[0-9]+$/\1/')

    if [[ ${FILEMATCHES[$filename_]} == "" ]]; then
      lines=()
      echo "Processing file: ${filename_}"

      # Get all occurences
      singlefile=$(echo ${filematches[@]} | grep -oE "(${filename_}:[0-9]+)" )

      for occurence in ${singlefile[@]}; do
        linenum=$(printf '%s' "${occurence}" | sed -r 's/^.*?:([0-9]+$)/\1/')
        lines+=(${linenum})
      done

      FILEMATCHES+=([$filename_]="${lines[*]}")
      lines_total=$(( ${lines_total} + ${#lines[@]} ))
      let files_total++

    fi
done

for filename in ${!FILEMATCHES[@]}; do
  echo "${esc}[35m${filename}${esc}[92m: ${esc}[31m${FILEMATCHES[$filename]}${esc}[0m"
done

printf "\nFound %d matching lines for pattern '%s' in %d files in package '%s'.\n\n" ${lines_total} "${2}" ${files_total} "${1}"
