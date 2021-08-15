#!/usr/bin/env bash
#
#   killns - Send signal to a process running in a specific Linux namespace (see 'man 7 signal')
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
