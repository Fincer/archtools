#!/bin/bash

##################################################
# Find line patterns in package files.
# Print matching file path and matching lines.

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

files=()
filename=""
lines=()
lines_total=0
files_total=0
esc=$(printf '\033')

for file in $(pacman -Ql "${1}" | sed "s/^${1}\s//g"); do
  if [[ -f "${file}" ]]; then

    line=$(grep --line-number --with-filename --binary-files=without-match -i "${2}" "${file}" | sed -r "s/^(.*?:)([0-9]+):.*/\1\2/g")

    for l in ${line[@]}; do

      linenum=$(printf '%s' ${l} | sed -r 's/^.*?:([0-9]+$)/\1/')
      filename_=$(printf '%s' ${l} | sed -r 's/^(.*?):[0-9]+$/\1/')

      lines+=(${linenum})

      if [[ ! "${filename}" == "${filename_}" ]]; then
        echo "${esc}[35m${filename_}${esc}[92m: ${esc}[31m${lines[*]}${esc}[0m"
        lines_total=$(( ${lines_total} + ${#lines[@]} ))
        let files_total++
        lines=()
      fi

      filename="${filename_}"
    done
  fi
done
printf "\nFound %d matching lines for pattern '%s' in %d files in package '%s'.\n\n" ${lines_total} "${2}" ${files_total} "${1}"
