#!/usr/bin/env bash
#
#   psns - List processes, their users and PIDs and their namespace name in current Linux namespaces
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
