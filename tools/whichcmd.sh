#!/bin/env sh

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
