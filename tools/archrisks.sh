#!/usr/bin/env bash
#
#    archrisks - Get security risk severity & count of installed packages on Arch Linux
#    Copyright (C) 2021,2024  Pekka Helenius
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.

#####################################

red=$'\33[91m'
orange=$'\033[38;5;208m'
yellow=$'\033[93m'
green=$'\033[92m'
reset=$'\033[0m'

typeset -A ARCH_MANAGERS

# List of known Arch Linux package managers + priority number for each
# Add more if you wish.
# Syntax guidelines:
# [<package manager priority (greater is more prioritized)>,<package manager>]="
# <parameter to refresh local pkg repositories>|
# <parameter to get detailed local pkg info>|
# <parameter to get name and version string of a pkg>|
# <parameter to get detailed remote pkg info>|
# <root=requires root, no_root=does not require root>
# "
ARCH_MANAGERS=(
    [0,/usr/bin/pacman]="-Syy|-Qi|-Q|-Si|root"
    [1,/usr/bin/pacaur]="-Syy|-Qi|-Q|-Si|no_root"
#    [2,yaourt]="-Syy|-Qi|-Q|-Si|no_root"
#    [3,pikaur]="-Syy|-Qi|-Q|-Si|no_root"
#    [4,pacget]="-Syy|-Qi|-Q|-Si|no_root"
#    [5,yay]="-Syy|-Qi|-Q|-Si|no_root"
#    [6,foxaur]="-Syy|-Qi|-Q|-Si|no_root"
#    [7,aurum]="-Syy|-Qi|-Q|-Si|no_root"
#    [8,goaur]="-Syy|-Qi|-Q|-Si|no_root"
#    [9,aurs]="-Syy|-Qi|-Q|-Si|no_root"
#    [10,magico]="-Syy|-Qi|-Q|-Si|no_root"
#    [11,maur]="-Syy|-Qi|-Q|-Si|no_root"
#    [12,pkgbuilder]="-Syy|-Qi|-Q|-Si|no_root"
#    [13,spinach]="-Syy|-Qi|-Q|-Si|no_root"
#    [14,trizen]="-Syy|-Qi|-Q|-Si|no_root"
)
SELECTED_MANAGER=
MANAGER_PRIORITY_LOWLIMIT=-1

SORT_ORDER="level"
SORT_REVERSE=0

NETWORK_HOST_ENDPOINT="security.archlinux.org"

input_count=${#@}
[[ "${input_count}" -eq 1 ]] && input_1="${1}"
[[ "${input_count}" -eq 2 ]] && input_1="${1}"; input_2="${2}"

usage() {
  echo -e "
Usage: $0
  -h|--help
  1st arg: --sort=<name,issues,level,status,desc> (optional)
  2nd arg: --reverse (optional)
"
  exit 0
}

input_parser() {

  if \
  [[ "${input_count}" -gt 2 ]] || \
  [[ "${input_1}" == "-h" ]] || \
  [[ "${input_1}" == "--help" ]]
  then
    usage

  elif [[ "${input_count}" -ne 0 ]]
  then
    SORT_ORDER=$(echo "${input_1}" | sed -r 's/^\-\-sort=(.*)/\1/')

    case "${SORT_ORDER}" in
      name|issues|level|version|desc)
        echo "Custom sort order selected: ${SORT_ORDER}"
        ;;
      *)
        echo "Unknown sorting order selected (${SORT_ORDER})."
        usage
    esac

    if [[ "${input_count}" -eq 2 ]]
    then
      case "${input_2}" in
        "--reverse")
          echo "Reverse ordering"
          SORT_REVERSE=1
          ;;
        *)
          echo "Unknown option '${input_2}'"
          SORT_REVERSE=0
      esac
    fi
  fi
}

connection_test() {

  local host_endpoint

  host_endpoint="${1}"

  if [[ $(ping -c 1 "${host_endpoint}" 2>&1 | grep -c "Name or service not known") -ne 0 ]]
  then
    echo -e "\nCan't connect to $host_endpoint. Please check your internet connection and try again.\n"
    exit 0
  fi

}

function find_my_package_manager() {

  local i
  local managers_list
  local managers_priority_list
  local manager_priority
  local manager

  i=0
  managers_list=()
  managers_priority_list=()

  for manager_str in ${!ARCH_MANAGERS[@]}; do

    OLDIFS=${IFS}
    IFS=","
    manager_array=(${manager_str})
    IFS=${OLDIFS}

    manager_priority="${manager_array[0]}"
    manager="${manager_array[1]}"

    if [[ "${manager_priority}" -lt "${MANAGER_PRIORITY_LOWLIMIT}" ]]
    then
      echo "Minimum priority is $((${MANAGER_PRIORITY_LOWLIMIT} + 1)). You have a package which has lower priority value. Exiting."
      exit 1
    fi

    if [[ $(type -P ${manager}) ]]
    then
      managers_list[$i]="${manager}"
      managers_priority_list[$i]=${manager_priority}
      let i++
    fi
  done

  if [[ ${#managers_list[@]} -eq 0 ]]
  then
    echo "Not any valid package manager found. Exiting."
    exit 1
  fi

  if [[ $(echo ${managers_priority_list[@]} | tr ' ' '\n' | uniq -d | wc -l) -ne 0 ]]
  then
    echo "Package managers with same priority found. Check internal manager list for duplicates. Exiting."
    exit 1
  fi

  # Select package manager by priority. Highest is selected.
  i=0
  while [[ "${i}" -le $((${#managers_list[@]} - 1)) ]]
  do
    if [[ ${managers_priority_list[i]} -gt ${priority_lowlimit} ]]
    then
      priority_lowlimit=${managers_priority_list[i]}
      SELECTED_MANAGER=${managers_list[i]}
    fi
    let i++
  done

  OLDIFS=${IFS}
  IFS="|"
  pkg_command=(${ARCH_MANAGERS["$priority_lowlimit,$SELECTED_MANAGER"]})
  IFS=${OLDIFS}

  command_refresh="${pkg_command[0]}"
  command_pkginfo_local="${pkg_command[1]}"
  command_pkginfo_local_short="${pkg_command[2]}"
  command_pkginfo_remote="${pkg_command[3]}"
  command_require_root="${pkg_command[4]}"

  if [[ "${command_require_root}" == "root" ]]
  then
    if [[ ! $(id -u) -eq 0 ]]
    then
      echo -e "\nThis command requires root privileges.\n"
      exit 0
    fi
  fi
}

# TODO: We can't really depend on parsing output strings since they vary between Arch package managers
package_version_parsed() {
  echo "${1}" | awk -F ' ' '{print $2}' | sed -r 's/[a-z]+.*//; s/[:_+-]/\./g; s/[^0-9]$//;'
}

package_version_check() {

  local system_version
  local repo_version
  local version_array_1
  local version_array_2
  local first_version_numbers
  local last_version_numbers
  local comparables
  local version_status_msg
  local check1
  local check2
  local s

  # Expected output syntax: "^<string> <version number>$"
  # TODO: We can't really depend on parsing output strings since they vary between Arch package managers
  system_version=$(${SELECTED_MANAGER} ${command_pkginfo_local_short} "${1}")
  repo_version=$(${SELECTED_MANAGER} ${command_pkginfo_remote} $1 | grep -E "^Version\s*:" | sed -r 's/.*(:\s*.*$)/\1/')

  version_array_1=$(package_version_parsed "${system_version}")
  version_array_2=$(package_version_parsed "${repo_version}")

  #Count of version elements (0 18 2 1 contains 4 numbers, for example)
  first_version_numbers=$(echo "${version_array_1}" | awk -F '.' '{print split($0, a)}')
  last_version_numbers=$(echo "${version_array_2}" | awk -F '.' '{print split($0, a)}')

  # Count of comparable version elements (maximum)
  # We compare this much of elements, not more
  if [[ "${last_version_numbers}" -lt "${first_version_numbers}" ]]
  then
    comparables="${last_version_numbers}"
  else
    comparables="${first_version_numbers}"
  fi

  # If all numbers are same, we don't analyze them more deeply.
  if [[ "${version_array_1}" == "${version_array_2}" ]]
  then
    version_status_msg="${green}Package is updated"
  else

    s=1
    while [ ${s} -le ${comparables} ]
    do
      check1=$(echo -e "${version_array_1}" | awk -v var=$s -F '.' '{print $var}')
      check2=$(echo -e "${version_array_2}" | awk -v var=$s -F '.' '{print $var}')

      if [[ ${check2} -gt ${check1} ]]
      then
        # Repo number is greater
        version_status_msg="${yellow}Update available"
        break

      elif [[ ${check2} -lt ${check1} ]]
      then
        # System number is greater
        version_status_msg="${reset}Newer package installed"
        break
      fi

      let s++
    done
  fi
  if [[ -z "${version_status_msg}" ]]
  then
    version_status_msg="${reset}Unknown"
  fi

  echo "${version_status_msg}"
}

exec_tool() {

  local i
  local package_count
  local risks_parsed_count
  local risks
  local description_column_max_chars

  local r_package_name
  local r_package_security_issues_count
  local r_package_security_issues_level
  local r_package_security_issues_level
  local r_package_description

  local risk_entries

  local sort_params
  local sort_column

  local package_alert_importance_status
  local package_alert_msg_color
  local package_alert_importance_output_status

  local package_security_issues_count
  local security_issues_package_summary
  local security_issues_total_count

  local security_msg_color

  i=1
  description_column_max_chars=35
  sort_params=()

  input_parser
  connection_test "${NETWORK_HOST_ENDPOINT}"
  find_my_package_manager

  echo "Security report date: $(date '+%d-%m-%Y, %X') (TZ: $(timedatectl status | grep "Time zone:" | awk '{print $3}'))"
  echo -e "\nSynchronizing package databases with ${SELECTED_MANAGER}\n"

  ${SELECTED_MANAGER} ${command_refresh} || exit

  if [[ ! $(type -P arch-audit) ]]
  then
    echo -e "\nCouldn't find Arch Linux security utility (arch-audit) in \$PATH. Please make sure it's installed.\n"
  else

    packages=
    package_count=0
    risks_parsed_count=0
    IFS=$'\n'
    for au in $(arch-audit); do
      package_name=$(echo "${au}" | awk -F ' ' '{print $1}')
      risk_level=$(echo "${au}" | grep -oE "Low|Medium|High|Critical")
      risks_count=$(echo "${au}" | grep -oP "(?<=by ).+(?=\. )" | sed 's/, /\n/g' | wc -l)
      risks[$package_count]="$package_name;$risk_level;$risks_count"
      packages="${packages}, ${package_name}"
      let package_count++
    done

    echo -e "Analyzing ${#risks[*]} vulnerable packages. This takes a while...\n"

    echo -e "Vulnerable packages are:\n\n$(echo ${packages} | sed 's/^, //')\n"

    for risk_parsed in ${risks[@]}; do

      OLDIFS=${IFS}
      IFS=";"
      risk_parsed=(${risk_parsed})
      IFS=${OLDIFS}

      # Package name
      r_package_name="${risk_parsed[0]}"

      echo -en "Analysing package ${i}/${#risks[*]} (${r_package_name})...                    \r"

      # Package security issues detected
      r_package_security_issues_count="${risk_parsed[2]}"

      # Package security issues overall level: Critical, High, Medium or Low
      r_package_security_issues_level=$(echo "${risk_parsed[1]}" | sed 's/Critical/0/g; s/High/1/g; s/Medium/2/g; s/Low/3/g')

      r_package_description=$(${SELECTED_MANAGER} "${command_pkginfo_local}" "${r_package_name}" | grep -i description | awk -F ": " '{print $2}')

      if [[ $(echo "${r_package_description}" | wc -m) -gt ${description_column_max_chars} ]]
      then
        r_package_description=$(printf "%s..." $(echo "${r_package_description}" | cut -c 1-${description_column_max_chars}))
      fi

      r_package_version_status=$(package_version_check "${r_package_name}")

      risk_entries[$risks_parsed_count]=$(printf "%s|%s|%s|%s|%s\n" \
        "${r_package_name}" \
        "${r_package_security_issues_count}" \
        "${r_package_security_issues_level}" \
        "${r_package_version_status}" \
        "${r_package_description}" \
      )

      let risks_parsed_count++
      let i++

    done

    echo -e "\e[1m"
    printf "\n%-25s%-20s%-15s%-25s%s\n" "Package" "Security issues" "Risk level" "Version status" "Description"
    echo -e "\e[0m"

    case "${SORT_ORDER}" in
      name)
        sort_column="-k1"
        ;;
      issues)
        sort_column="-k2"
        sort_params+=("-n")
        ;;
      level)
        sort_column="-k3"
        ;;
      version)
        sort_column="-k4"
        ;;
      desc)
        sort_column="-k5"
        ;;
      #*)
      #    echo "Unknown sorting order selected. Exiting."
      #    exit 1
    esac

    if [[ "${SORT_REVERSE}" -eq 1 ]]
    then
      sort_params+=("-r")
    fi

    i=0
    IFS=$'\n'
    for line in $(echo "${risk_entries[*]}" | sort ${sort_params[*]} -t'|' ${sort_column})
    do

      package_alert_importance_status=$(echo "${line}" | awk -F '|' '{print $3}')

      case "${package_alert_importance_status}" in
        0)
          package_alert_msg_color="${red}"
          package_alert_importance_output_status="Critical"
          ;;
        1)
          package_alert_msg_color="${orange}"
          package_alert_importance_output_status="High"
          ;;
        2)
          package_alert_msg_color="${yellow}"
          package_alert_importance_output_status="Medium"
          ;;
        3)
          package_alert_msg_color="${green}"
          package_alert_importance_output_status="Low"
          ;;
      esac

      package_security_issues_count=$(echo "${line}" | awk -F '|' '{print $2}')

      if [[ ${package_security_issues_count} -lt 5 ]]
      then
        security_msg_color="${green}"
      elif [[ ${package_security_issues_count} -ge 5 ]] && [[ ${package_security_issues_count} -lt 10 ]]
      then
        security_msg_color="${yellow}"
      elif [[ ${package_security_issues_count} -ge 10 ]] && [[ ${package_security_issues_count} -lt 20 ]]
      then
        security_msg_color="${orange}"
      else
        security_msg_color="${red}"
      fi

      security_issues_package_summary[$i]=${package_security_issues_count}

      echo "${line}" | awk -F '|' \
        -v clr1="${package_alert_msg_color}" \
        -v clr2="${security_msg_color}" \
        -v rs="${reset}" \
        -v var="${package_alert_importance_output_status}" \
        '{printf "%-25s%s%-20s%s%-15s%-30s%s%s\n",$1,clr2,$2,clr1,var,$4,rs,$5}'

      let i++
    done

    security_issues_total_count=$(echo $(printf "%d+" "${security_issues_package_summary[@]}")0 | bc)

    echo -e "\nTotal:"
    printf "%-25s%s\n\n" "${package_count}" "${security_issues_total_count}"
    printf "Check %s for more information.\n\n" "${NETWORK_HOST_ENDPOINT}"
  fi
}

exec_tool
