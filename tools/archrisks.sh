#!/usr/bin/env bash
#
#    archrisks - Get security risk severity & count of installed packages on Arch Linux
#    Copyright (C) 2021  Pekka Helenius
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

priority_lowlimit=-1
default_order="level"
default_reverse=0

provider="security.archlinux.org"





input_count=${#@}
[[ $input_count -eq 1 ]] && input_1=${1}
[[ $input_count -eq 2 ]] && input_1=${1}; input_2=${2}

function helpCaller() {
    echo -e "
Usage: $0
         -h|--help
1st arg: --sort=<name,issues,level,status,desc> (optional)
2nd arg: --reverse (optional)
"
    exit 0
}

function inputParser() {

    if [[ ${input_count} -gt 2 ]] || [[ ${input_1} == "-h" ]] || [[ ${input_1} == "--help" ]]; then
        helpCaller
    elif [[ ${input_count} -eq 0 ]]; then
        sort_order=${default_order}
        sort_reverse=${default_reverse}
    else
        sort_order=$(echo ${input_1} | sed -r 's/^\-\-sort=(.*)/\1/')

        case ${sort_order} in
            name|issues|level|version|desc)
                echo "Custom sort order selected: ${sort_order}"
                ;;
            *)
                echo "Unknown sorting order selected (${sort_order})."
                helpCaller
        esac

        if [[ ${input_count} -eq 2 ]]; then
            case ${input_2} in
                "--reverse")
                    echo "Reverse ordering"
                    sort_reverse=1
                    ;;
                *)
                    echo "Unknown option '${input_2}'"
                    sort_reverse=${default_reverse}
            esac
        fi

    fi
}

function internetTest() {
    if [[ $(ping -c 1 $provider 2>&1 | grep -c "Name or service not known") -ne 0 ]]; then
        echo -e "\nCan't connect to $provider. Please check your internet connection and try again.\n"
        exit 0
    fi
}

function findMyPackageManager() {

    i=0
    for managerStr in ${!ARCH_MANAGERS[@]}; do

        manager_priority=$(echo ${managerStr} | awk -F ',' '{print $1}')
        manager=$(echo ${managerStr} | awk -F ',' '{print $2}')

        if [[ ${manager_priority} -lt ${priority_lowlimit} ]]; then
            echo "Minimum priority is $((${priority_lowlimit} + 1)). You have a package which has lower priority value. Exiting."
            exit 1
        fi

        if [[ $(echo $(which ${manager} &>/dev/null)$?) -eq 0 ]]; then
            managers_list[$i]=${manager}
            managers_priority_list[$i]=${manager_priority}
            let i++
        fi
    done

    if [[ ${#managers_list[@]} -eq 0 ]]; then
        echo "Not any valid package manager found. Exiting."
        exit 1
    fi

    if [[ $(echo ${managers_priority_list[@]} | tr ' ' '\n' | uniq -d | wc -l) -ne 0 ]]; then
        echo "Package managers with same priority found. Check internal manager list for duplicates. Exiting."
        exit 1
    fi

    # Select package manager by priority. Highest is selected.
    i=0
    while [[ ${i} -le $((${#managers_list[@]} - 1)) ]]; do
        if [[ ${managers_priority_list[i]} -gt ${priority_lowlimit} ]]; then
            priority_lowlimit=${managers_priority_list[i]}
            selected_manager=${managers_list[i]}
        fi
        let i++
    done

    pkg_command=${ARCH_MANAGERS["$priority_lowlimit,$selected_manager"]}

    command_refresh=$(echo $pkg_command | awk -F '|' '{print $1}')
    command_pkginfo_local=$(echo $pkg_command | awk -F '|' '{print $2}')
    command_pkginfo_local_short=$(echo $pkg_command | awk -F '|' '{print $3}')
    command_pkginfo_remote=$(echo $pkg_command | awk -F '|' '{print $4}')
    command_require_root=$(echo $pkg_command | awk -F '|' '{print $5}')

    if [[ ${command_require_root} == "root" ]]; then
        if [[ ! $(id -u) -eq 0 ]]; then
            echo -e "\nThis command requires root privileges.\n"
            exit 0
        fi
    fi

}

function runTool() {
    echo "Security report date: $(date '+%d-%m-%Y, %X') (TZ: $(timedatectl status | grep "Time zone:" | awk '{print $3}'))"

    echo -e "\nSynchronizing package databases with ${selected_manager}\n"
    ${selected_manager} ${command_refresh} || exit

    if [[ ! $(which arch-audit | wc -l) -eq 1 ]]; then
        echo -e "\nCouldn't find Arch Linux security utility (arch-audit) in \$PATH. Please make sure it's installed.\n"
    else

        count=0
        prs_count=0
        IFS=$'\n'

        for i in $(arch-audit); do
            package_name=$(echo "$i" | awk -F ' ' '{print $1}')
            risk_level=$(echo "$i" | grep -oE "Low|Medium|High|Critical")
            risks_count=$(echo "$i" | grep -oP "(?<=by ).+(?=\. )" | sed 's/, /\n/g' | wc -l)
            #risks_count=$(echo "$i" | awk -F 'CVE' '{print NF-1}')

            risks[$count]="$package_name $risk_level $risks_count"

            let count++
        done

        echo -e "\nAnalyzing ${#risks[*]} vulnerable packages. This takes a while...\n"

        i=1
        for risk_parsed in $(echo "${risks[*]}"); do

            echo -en "Analysing package ${i}/${#risks[*]}...          \r"

            # Package in question
            col1=$(echo "$risk_parsed" | awk -F ' ' '{print $1}')

            # Security issues detected
            col2=$(echo "$risk_parsed" | awk -F ' ' '{print $3}')

            #Critical, High, Medium or Low risk
            col3=$(echo "$risk_parsed" | awk -F ' ' '{print $2}' | sed 's/Critical/0/g; s/High/1/g; s/Medium/2/g; s/Low/3/g')

            col5=$(${selected_manager} ${command_pkginfo_local} $col1 | grep -i description | awk -F ": " '{print $2}')
            maxchars=35

            if [[ $(echo $col5 | wc -m) -gt $maxchars ]]; then
                col5=$(echo "$(echo $col5 | cut -c 1-$maxchars)...")
            fi

            versioncheck() {

                # TODO: We can't really depend on parsing output strings since they vary between Arch package managers
                parsedver() {
                    echo $1 | awk -F ' ' '{print $2}' | sed -r 's/[a-z]+.*//; s/[:_+-]/\./g; s/[^0-9]$//;'
                }

                # Expected output syntax: "^<string> <version number>$"
                # TODO: We can't really depend on parsing output strings since they vary between Arch package managers
                system_version=$(${selected_manager} ${command_pkginfo_local_short} $1)
                repo_version=$(${selected_manager} ${command_pkginfo_remote} $1 | grep -E "^Version\s*:" | sed -r 's/.*(:\s*.*$)/\1/')

                version_array_1=$(parsedver $system_version)
                version_array_2=$(parsedver $repo_version)

                #Count of version elements (0 18 2 1 contains 4 numbers, for example)
                firstvernums=$(echo $version_array_1 | awk -F '.' '{print split($0, a)}')
                lastvernums=$(echo $version_array_2 | awk -F '.' '{print split($0, a)}')

                # Count of comparable version elements (maximum)
                # We compare this much of elements, not more
                if [[ $lastvernums -lt $firstvernums ]]; then
                    comparables=$lastvernums
                else
                    comparables=$firstvernums
                fi

                # If all numbers are same, we don't analyze them more deeply.
                if [[ $version_array_1 == $version_array_2 ]]; then
                    col4="${green}Package is updated"
                else

                    s=1
                    while [ $s -le $comparables ]; do

                        check1=$(echo -e $version_array_1 | awk -v var=$s -F '.' '{print $var}')
                        check2=$(echo -e $version_array_2 | awk -v var=$s -F '.' '{print $var}')

                        if [[ $check2 -gt $check1 ]]; then
                            # Repo number is greater
                            col4="${yellow}Update available"
                            break

                        elif [[ $check2 -lt $check1 ]]; then
                            # System number is greater
                            col4="${reset}Newer package installed"
                            break
                        fi

                        let s++
                    done
                fi
            }

            versioncheck $col1

            risk_entries[$prs_count]=$(printf "%s|%s|%s|%s|%s\n" "$col1" "$col2" "$col3" "$col4" "$col5")

            let prs_count++
            let i++

        done

        echo -e "\e[1m"
        printf "\n%-25s%-20s%-15s%-25s%s\n" "Package" "Security issues" "Risk level" "Version status" "Description"
        echo -e "\e[0m"

        sort_params=()
        case ${sort_order} in
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

        if [[ ${sort_reverse} == 1 ]]; then
            sort_params+=("-r")
        fi

        i=0
        for line in $(echo "${risk_entries[*]}" | sort ${sort_params[*]} -t'|' ${sort_column}); do

            if [[ $(echo "$line" | awk -F '|' '{print $3}') -eq 0 ]]; then
                alert_color="${red}"
                importance="Critical"

            elif [[ $(echo "$line" | awk -F '|' '{print $3}') -eq 1 ]]; then
                alert_color="${orange}"
                importance="High"

            elif [[ $(echo "$line" | awk -F '|' '{print $3}') -eq 2 ]]; then
                alert_color="${yellow}"
                importance="Medium"

            elif [[ $(echo "$line" | awk -F '|' '{print $3}') -eq 3 ]]; then
                alert_color="${green}"
                importance="Low"
            fi

            sec_count=$(echo "$line" | awk -F '|' '{print $2}')

            if [[ $sec_count -lt 5 ]]; then
                secclr="${green}"
            elif [[ $sec_count -ge 5 ]] && [[ $sec_count -lt 10 ]]; then
                secclr="${yellow}"
            elif [[ $sec_count -ge 10 ]] && [[ $sec_count -lt 20 ]]; then
                secclr="${orange}"
            elif [[ $sec_count -ge 20 ]]; then
                secclr="${red}"
            fi

            secsum[$i]=$sec_count

            echo "$line" | awk -F '|' -v clr1="${alert_color}" -v clr2="${secclr}" -v rs="${reset}" -v var="${importance}" '{printf "%-25s%s%-20s%s%-15s%-30s%s%s\n",$1,clr2,$2,clr1,var,$4,rs,$5}'

            let i++
        done

        secsums_total=$(echo $(printf "%d+" ${secsum[@]})0 | bc)

        echo -e "\nTotal:"
        printf "%-25s%s\n\n" "$count" "$secsums_total"
        printf "Check %s for more information.\n\n" "${provider}"
    fi
}

inputParser
findMyPackageManager
internetTest
runTool
