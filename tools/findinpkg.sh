#!/bin/bash

##################################################
# Find line patterns in package files.
# Print matching file path and matching lines.

function help() {
  echo -e "Usage: findinpkg <pkgname> <pattern-to-search>"
  exit
}

if [[ $# -ne 2 ]]; then
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

separate() {
  linenro=$(printf '%s' ${1} | sed -r 's/^.*?:([0-9]+$)/\1/')
  filename_=$(printf '%s' ${1} | sed -r 's/^(.*?):[0-9]+$/\1/')

  if [[ "${filename}" == "" ]]; then filename=${filename_}; fi

  let lines_total++
  if [[ ! "${filename}" == "${filename_}" ]]; then
    echo "${esc}[35m${filename}${esc}[92m: ${esc}[31m${lines[*]}${esc}[0m"
    let files_total++
    lines=()
  fi
  filename="${filename_}"
  lines+=(${linenro})
  let lines_total++
}

for file in $(pacman -Ql "${1}" | sed "s/^${1}\s//g"); do
  if [[ -f "${file}" ]]; then
    line=$(grep --line-number --with-filename --binary-files=without-match -i "${2}" "${file}" | sed -r "s/^(.*?:)([0-9]+):.*/\1\2/g")
    for l in ${line[@]}; do
      separate "${l}"
    done
  fi
done
printf "\nFound %d matching lines for pattern '%s' in %d files in %s package.\n" ${lines_total} "${2}" ${files_total} "${1}"
