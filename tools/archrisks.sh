#!/bin/bash

#    archrisks - Security information tool for Arch Linux
#    Copyright (C) 2018  Pekka Helenius
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

######################################################################################################################

if [[ ! $(id -u) -eq 0 ]]; then  
    echo -e "\nThis command requires root privileges.\n"
    exit
fi

echo "Security report date: $(date '+%d-%m-%Y, %X') (TZ: $(timedatectl status | grep "Time zone:" | awk '{print $3}'))"

red=$'\33[91m'
orange=$'\033[38;5;208m'
yellow=$'\033[93m'
green=$'\033[92m'
reset=$'\033[0m'

PROVIDER="security.archlinux.org"

# pacman, pacaur or yaourt. Please make sure all parameters used in this script are accepted by PKGMGR
PKGMGR="pacman"

INTERNET_TEST=$(ping -c 1 $PROVIDER 2>&1 | grep -c "Name or service not known")

if [[ ! $INTERNET_TEST -eq 0 ]]; then
    echo -e "\nCan't connect to $PROVIDER. Please check your internet connection and try again.\n"
else

    echo -e "\nSynchronizing package databases with $PKGMGR\n"
    $PKGMGR -Syy || return

    if [[ ! $(which arch-audit | wc -l) -eq 1 ]]; then
        echo -e "\nCouldn't find Arch Linux security utility (arch-audit). Please make sure it's installed.\n"
    else

        CNT=0
        PRSCNT=0

        # Internal Field Separator. This variable determines how Bash recognizes fields, or word boundaries, when it interprets character strings.
        IFS=$'\n'

        for i in $(arch-audit); do
            PACKAGENAME=$(echo "$i" | awk -F ' ' '{print $2}')
            RISKLEVEL=$(echo "$i" | grep -oE "Low|Medium|High|Critical")
            RISKSCOUNT=$(echo "$i" | awk -F 'CVE' '{print NF-1}')

            RISKS[$CNT]="$PACKAGENAME $RISKLEVEL $RISKSCOUNT"

            let CNT++
        done

        echo -e "\e[1m"
        printf "%-25s%-20s%-15s%-25s%s\n" "Package" "Security issues" "Risk level" "Version status" "Description"
        echo -e "\e[0m"

        for RISK_PARSED in $(echo "${RISKS[*]}"); do

            # Package in question
            col1=$(echo "$RISK_PARSED" | awk -F ' ' '{print $1}')

            # Security issues detected
            col2=$(echo "$RISK_PARSED" | awk -F ' ' '{print $3}')

            #Critical, High, Medium or Low risk
            col3=$(echo "$RISK_PARSED" | awk -F ' ' '{print $2}' | sed 's/Critical/0/g; s/High/1/g; s/Medium/2/g; s/Low/3/g')

            col5=$($PKGMGR -Qi $col1 |grep -i description | awk -F ": " '{print $2}')
            maxchars=35

            if [[ $(echo $col5 | wc -m) -gt $maxchars ]]; then
                col5=$(echo "$(echo $col5 | cut -c 1-$maxchars)...")
            fi

            #pkgurl=$(pacaur -Qi $col1 |grep URL | awk -F ": " '{print $2}')

            versioncheck() {

                parsedver() {

                    TRIMMED=$(echo $1 | sed 's/[:.-]/./g')

                    if [[ $TRIMMED =~ [A-Za-z] ]]; then

                        PKGVERCHARS=$(echo $TRIMMED | sed 's/[^a-zA-Z]//g')

                        CHARNUM=0
                        for char in $PKGVERCHARS; do
                            charnum=$(echo {a..z} | sed 's/ //g' | grep -b -o $char | awk 'BEGIN {FS=":"}{print $1}')
                            REP[$CHARNUM]="s/$char/$charnum/g;"
                            let CHARNUM++
                        done

                        for seds in "${REP[*]}"; do
                            SEDSTR=$seds
                        done

                        echo $TRIMMED | sed "$SEDSTR"

                    else
                        echo $TRIMMED
                    fi
                }

                SYSVER=$($PKGMGR -Q $1 | awk -F ' ' '{print $2}')
                REPOVER=$($PKGMGR -Si $1 | grep "Version.*:" | awk -F ' ' '{print $3}')

                VERARRAY1=$(parsedver $SYSVER)
                VERARRAY2=$(parsedver $REPOVER)

                #Count of version elements (0 18 2 1 contains 4 numbers, for example)
                firstvernums=$(echo $VERARRAY1 | awk -F '.' '{print split($0, a)}')
                lastvernums=$(echo $VERARRAY2 | awk -F '.' '{print split($0, a)}')

                # Count of comparable version elements (maximum)
                # We compare this much of elements, not more
                if [[ $lastvernums -lt $firstvernums ]]; then
                    comparables=$lastvernums
                else
                    comparables=$firstvernums
                fi

                # If all numbers are same, we don't analyze them more deeply.
                if [[ $VERARRAY1 == $VERARRAY2 ]]; then
                    col4="${green}Package is updated"
                else

                    s=1
                    while [ $s -le $comparables ]; do

                        check1=$(echo -e $VERARRAY1 | awk -v var=$s -F '.' '{print $var}')
                        check2=$(echo -e $VERARRAY2 | awk -v var=$s -F '.' '{print $var}')

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

            RISKENTRIES[$PRSCNT]=$(printf "%s|%s|%s|%s|%s\n" "$col1" "$col2" "$col3" "$col4" "$col5")

            let PRSCNT++

        done

        i=0
        for line in $(echo "${RISKENTRIES[*]}" | sort -t'|' -k3); do

            if [[ $(echo "$line" | awk -F '|' '{print $3}') -eq 0 ]]; then
                alertclr="${red}"
                IMPT="Critical"

            elif [[ $(echo "$line" | awk -F '|' '{print $3}') -eq 1 ]]; then
                alertclr="${orange}"
                IMPT="High"

            elif [[ $(echo "$line" | awk -F '|' '{print $3}') -eq 2 ]]; then
                alertclr="${yellow}"
                IMPT="Medium"

            elif [[ $(echo "$line" | awk -F '|' '{print $3}') -eq 3 ]]; then
                alertclr="${green}"
                IMPT="Low"
            fi

            SECCOUNT=$(echo "$line" | awk -F '|' '{print $2}')

            if [[ $SECCOUNT -lt 5 ]]; then
                secclr="${green}"
            elif [[ $SECCOUNT -ge 5 ]] && [[ $SECCOUNT -lt 10 ]]; then
                secclr="${yellow}"
            elif [[ $SECCOUNT -ge 10 ]] && [[ $SECCOUNT -lt 20 ]]; then
                secclr="${orange}"
            elif [[ $SECCOUNT -ge 20 ]]; then
                secclr="${red}"
            fi

            secsum[$i]=$SECCOUNT

            echo "$line" | awk -F '|' -v clr1="${alertclr}" -v clr2="${secclr}" -v rs="${reset}" -v var="${IMPT}" '{printf "%-25s%s%-20s%s%-15s%-30s%s%s\n",$1,clr2,$2,clr1,var,$4,rs,$5}'

            let i++
        done

        secsums_total=$(echo $(printf "%d+" ${secsum[@]})0 | bc)

        echo -e "\nTotal:"
        printf "%-25s%s\n\n" "$CNT" "$secsums_total"
    fi
fi
