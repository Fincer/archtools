#!/bin/env sh

if [[ ${1} =~ ^(\-h|\-\-help)$ ]] || [[ -z ${1} ]]; then
  echo "
Send a signal to a process in specified namespace.

usage: $(basename $0) <signal> <processname> <namespace>
"
  exit 0
fi

signal="${1}"
processname="${2}"
namespace="${3}"

for pid in $(sudo ip netns pids ${namespace}); do

  if [[ $(sudo ps -q $pid -o command) =~ ^.*${processname}.* ]]; then
    sudo ip netns exec ${namespace} kill -${signal} ${pid}
  fi

done
