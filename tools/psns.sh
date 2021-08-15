#!/bin/env sh

NAMESPACES=( $(ls /run/netns) )

if [[ ${1} =~ ^(\-h|\-\-help)$ ]]; then
  echo "
List processes in non-default namespaces.
"
  exit 0
fi

printf "%-25s%-20s%-20s%s%-15s%-30s%s\n" "USER" "PID" "COMMAND" "NAMESPACE"
echo "--------------------------------------------------------------------------"

for namespace in ${NAMESPACES[@]}; do

  for pid in $(sudo ip netns pids ${namespace}); do

    printf "%-25s%-20s%-20s%s%-15s%-30s%s\n" $(ps -q ${pid} -o uname,pid,comm= | tail -1) ${namespace}
  done

done

echo "To alter a process, use: $(killns)"
