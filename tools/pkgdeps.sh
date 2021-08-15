#!/usr/bin/env bash
#
#    pkgdeps - Recursive shared library & executable dependency finder for Arch Linux
#
#    Copyright (C) 2021  Pekka Helenius <pekka.helenius@fjordtek.com>
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

# TODO print stored dependency packages as red if errors encountered
# TODO check packages themselves, too (not only their dependencies...)

# TODO: Does not give a correct result
# Depends on:                        libtinfo.so.6                 Provided by:

# TODO: Implement 'Do you mean <package>?' code logic, when the following occurs:
# Error: octopi not found. Skipping.

# -------------------------------------------
# BUG
# Ignore rules.d folder since it gives permission denial errors

#####################################
# Look for missing library files for installed packages

red=$'\33[91m'
orange=$'\033[38;5;208m'
yellow=$'\033[93m'
green=$'\033[92m'
blue=$'\033[94m'
bold=$'\033[1m'
reset=$'\033[0m'

PACMAN_EXEC="/usr/bin/pacman"
LOGFILE="/var/log/pacman.log"

COMMANDS=(sudo pacman date ping package-query)

for com in $COMMANDS; do
  if [[ ! $(which $com |grep "which: no $com in" | wc -w) -eq 0 ]]; then
    echo -e "\nCommand $com not found. Can't run the script.\n"
    return
  fi
done

echo -e "\n${bold}Dependency tracker - Find broken executables & libraries${reset}"

function checklocaldirs() {

  unset PKG

  for filepkgdir in $1; do
    #echo "Search dir is $filepkgdir Search term is $2"
    findfile=$(find "$filepkgdir" -maxdepth 1 -type f -iname "*$2*")

    if [[ -f $findfile ]]; then
      PKG="$(${PACMAN_EXEC} -Qo $findfile | awk '{print $5 " " $6}')"
      return
    fi

  done
}

function checkrepopkgs() {

  unset PKG
  unset NIPKG
  REPOPKGS=$(${PACMAN_EXEC} -Fs $1 | sed '2~2d' | awk -F '[/ ]' '{print $2}')

  if [[ ! -z $REPOPKGS ]]; then

    c=0

    for repopkg in $REPOPKGS; do
      t=0

      for repopkgfile in $(${PACMAN_EXEC} -Fl "$repopkg" | awk '{print "/"$2}'); do
        if [[ -f $repopkgfile ]]; then 
          REPOPKGFILES[$t]="$repopkgfile"
          let t++
        fi
      done

      if [ ! "${#REPOPKGFILES[@]}" -eq 0 ]; then

        for matchrepofile in "${REPOPKGFILES[@]}"; do
          if [[ "${matchrepofile}" == "${2}" ]]; then
            PKG=$repopkg
            return
          # else
            # if [[ $(${PACMAN_EXEC} -Qo $matchrepofile | grep -o "owned by" | wc -w) -eq 2 ]]
              # PKG=$(echo "${REPOPKGS[*]}?" | tr '\n' ',' | sed 's/\,*$//g')
              # return
          fi

        done
        unset REPOPKGFILES

      else
        #echo "do we get here $repopkg"
        if [[ $(${PACMAN_EXEC} -Q $repopkg &>/dev/null || echo "was not found" | wc -l) -eq 1 ]]; then
          NIPKG[$c]="$repopkg"
          let c++
        fi
        #PKG="${red}N/A${reset}"

      fi
    done
    #PKG="${red}N/A${reset}"
  else
    PKG="${red}N/A${reset}"
  fi
}

function checkconnection() {

  PROVIDER="luna.archlinux.org"

  INTERNET_TEST=$(ping -c 1 $PROVIDER 2>&1 | grep -c "Name or service not known")

  if [[ ! $INTERNET_TEST -eq 0 ]]; then
    echo -e "\n${red}Error:${reset} Can't connect to $PROVIDER. Please check your internet connection.\n"
  else
    echo -e "\nUpdating file databases with pacman (root required)\n"
    sudo ${PACMAN_EXEC} -Fy
  fi
}

if [[ $# -eq 1 ]]; then
  ${PACMAN_EXEC} -Q $1 2> /dev/null #|| echo 'something' # TODO silent normal output!
  if [[ $? -eq 1 ]]; then
    seterror=1
  else
    seterror=0
  fi
else
  seterror=0
fi

#####################################

if [[ ${#} -lt 1 ]]; then
  echo -e  "\nPlease give a name of an installed package\n"
  exit 1
fi

if [[ -f $LOGFILE ]] && [[ $seterror -ne 1 ]]; then

  LASTRUN_TIMESTAMP=$(awk '/pacman -Fy/ {a=$0} END{print a}' $LOGFILE | awk -F'[][]' '{print $2}')
  LASTRUN=$(date --date="${LASTRUN_TIMESTAMP}" +%s)

  if [[ $? -ne 0 ]]; then
    echo -e " ${red}Error:${reset} Can't parse the latest 'pacman -Fy' date value from pacman log file $LOGFILE! Skipping database update.\n"
  else

    if [[ $(echo $LASTRUN | wc -w) -eq 1 ]]; then

      CURTIME=$(date +"%s")
      LASTUPDATE=$(( ($CURTIME - $LASTRUN)/60 ))
      TIME_THRESHOLD=180 # 3 hours

      if [[ $LASTUPDATE -ge $TIME_THRESHOLD ]]; then
        echo -e "\nPackage databases were last updated $LASTUPDATE minutes ago.\n" # TODO minutes....hours...days...ago...

        read -r -p "Do you want to update databases now? [y/N] " dbupdate
        if [[ $(echo $dbupdate | sed 's/ //g') =~ ^([yY][eE][sS]|[yY])$ ]]; then
          checkconnection
        else
          echo -e "\nSkipping database update.\n"
        fi
      else
        echo -e "\nPackage databases are updated.\n"
      fi
    else
      echo -e "\nPrevious database update timestamp not found. Updating...\n"
      checkconnection
    fi
  fi

elif [[ ! -f $LOGFILE ]]; then
  echo -e "\n ${red}Error:${reset} Pacman log file not found.\n"
fi

pkgcount=$#
curpkgcount=1
typeset -A CHECKEDLIST

# Loop through all input arguments (package names)
for p in $(echo "${@}"); do # TODO show how many dependencies this package has if more than 1

  LOCALDIRS=("/usr/lib" "/usr/bin" "/usr/lib/" "/opt/")

  w=0
  for dir in $(${PACMAN_EXEC} -Qql $p 2> /dev/null); do
    if [[ -d $dir ]]; then
      MAINPKGDIRS[$w]="${dir}"
      let w++
    fi
  done

  echo -e "----------------------------------------"
  echo -e "\n$curpkgcount/$pkgcount ($((100*$curpkgcount/$pkgcount))%) - ${orange}$p${reset}"

  # Check that the input package can actually be found
  if [[ $(${PACMAN_EXEC} -Qi $p &>/dev/null || echo "was not found" | wc -l) -eq 1 ]]; then
    echo -e "\n ${red}Error:${reset} package ${orange}$p${reset} not found. Skipping.\n"
  else

    # Parse dependencies of the selected package to a string list
    PKGDEPS=$(${PACMAN_EXEC} -Qi $p | grep "Depends On" | sed 's/.*: //g; s/  / /g')

    #Parse optional dependencies
    PKGDEPS_OPT=$(${PACMAN_EXEC} -Qi $p | grep "Optional Deps" | sed 's/.*\s: //; s/  / /')

    # Loop for each package ([@] means array value X)
    # We circumvent a pacman bug/issue here
    # pacman does a hard fixed listing for packages, meaning it doesn't recognize "provides" option
    # This is mainly a problem of git package versions
    #
    if [[ $PKGDEPS_OPT != "None" ]]; then
      echo -e "\nOptional dependencies for ${orange}$p${reset} :\n\n $PKGDEPS_OPT"
    fi

    if [[ $PKGDEPS != "None" ]]; then
      echo -e "\nRequired dependencies for ${orange}$p${reset} :\n" #  TODO go even one step deeper with these!

      for i in $(echo "${PKGDEPS[@]}"); do

        function parseversion() {
          pattern="[<=>]"
          if [[ $i =~ $pattern ]]; then
            i=$(echo $i | awk -F'[<=>]' '{print $1}')
            # TODO do version check here as done in 'risks' function?
            #i_ver=$(echo $i | awk -F'[<=>]' '{print $3}')
            #return $pkgname $pkgver
          #else
            #return $i
          fi
        }

        parseversion
        # Error (package was not found)
        if [[ $(${PACMAN_EXEC} -Qi $i &>/dev/null || echo "was not found" | wc -l) -eq 1 ]]; then

          # Get name of the package which provides the dependency
          ALTDEP=$(${PACMAN_EXEC} -Qi | grep -iE "Name|Provides" | grep $i | grep "Name" | sed 's/.*: //')

          o=0
          for altdep in $ALTDEP; do
            ALTDEPS[$o]=$altdep
            let o++
          done

          function deepscan() {
            MAINPKGFILES=$(${PACMAN_EXEC} -Qql $p)

            for mainpkgfile in $MAINPKGFILES; do

              if [[ $(mimetype "${mainpkgfile}" | grep -iE "x\-sharedlib|x\-executable" | wc -l) -eq 1 ]]; then

                for deepscan in $(ldd "${mainpkgfile}" | awk '{print $3}' | sed '/^\s*$/d'); do
                  OWNER_DEEPSCAN=$(${PACMAN_EXEC} -Qo $deepscan | awk '{print $5}')

                  for item in "${ALTDEPS[@]}"; do

                    if [[ $OWNER_DEEPSCAN == "$item" ]]; then
                      i=$OWNER_DEEPSCAN
                      return 0
                    fi

                  done

                done
              fi
            done
            return 1
          }

          deepscan
          if [[ $? -eq 1 ]]; then
            #Get 'provides' from arch package database
            FETCHEDPKGS=$(package-query --qprovides "$i" -Q -f "%n")
            k=0

            for fetch in $FETCHEDPKGS; do
              if [[ ! $(${PACMAN_EXEC} -Q $fetch &>/dev/null || echo "was not found" | wc -l) -eq 1 ]]; then
                i="$fetch"
                break
                # TODO show here the true 'depends on' stuff, not just 'provided by' package? bash <-> sh conversion for example
              else
                echo -e " ${yellow}Warning:${reset} Dependency '$i' not found and not recognized as a provided package"
                i="notfound"
                NOTFOUNDS[$k]=$i
                let k++
              fi
            done
          fi
        fi

        if [[ $i != "notfound" ]] && [[ -z ${CHECKEDLIST[$i]} ]]; then

          FILES=$(${PACMAN_EXEC} -Qql $i)
          x=0
          printf " %-30s%s\r" "$i" "Searching libraries/executables"

          for mimefile in $FILES; do

            if [[ $(file --mime-type "${mimefile}" | grep -iE "executable" | wc -l) -eq 1 ]]; then
              MIMEFILES[$x]="${mimefile}"
              let x++
              printf " %-30s%s\r" "$i" "Found libraries/executables: $x " #Yes, the trailing space is meant to be here
            fi
          done

          if [[ $x -gt 0 ]]; then
            CHECKEDLIST[$i]=$(printf " %-30s%s\n" "$i" "Found libraries/executables: $x")
          else
            CHECKEDLIST[$i]=$(printf " %-30s%s\n" "$i" "No libraries/executables")
          fi

          # Replace the current line (100 characters) with empty space and fill it with checkedlist value
          echo -e "\r$(for ((i = 0; i < 100; i++)); do echo -n ' '; done)\r${CHECKEDLIST[$i]}"

          # Go through all listed library & executable files
          for n in $(echo "${MIMEFILES[@]}"); do

            # Get count of all matching lines for a file. If no errors, this should return 1
            # Enable bash debugging with set -x and run it in subshell (otherwise we need to use set +x to disable debugging)
            # As debugging output is considered as STDERR (not default STDOUT), we pipe it with |&
            # Suppress ldd warning messages ("you have no permission") as they are not relevant here and delete empty lines

            escapechars="]["
            n=$(echo "${n}" | sed -r 's/(['"$escapechars"'])/\\\1/g')

            LDDCMDCNT=$( (set -x; ldd "${n}" |grep -i "not found") |& grep -E "${n}|=> not found" | sed 's/.*warning.*//g; /^\s*$/d' | wc -l)

            # Get all lines for a file. If no errors, this should return only "++ ldd <filename>"
            LDDCMD=$( (set -x; ldd "${n}" |grep -i "not found") |& grep -E "${n}" | sed 's/.*warning.*//g; /^\s*$/d')
            LDDCMD_FILE=$(echo "$LDDCMD " | sed 's/++ ldd //g')

            # Basename doesn't accept empty/null parameters
            if [[ ! -z "${LDDCMD_FILE// }" ]]; then
              LDDCMD_FILE_BASENAME=$(basename $LDDCMD_FILE) # | sed "s/[-0-9.]*$//"
            fi

            # If we have match for "not found" messages, print the output
            if [[ $LDDCMDCNT -gt 1 ]]; then
              LIBNOTFOUND=true

              checkrepopkgs $LDDCMD_FILE_BASENAME $LDDCMD_FILE
              # MAINPKG=$PKG
              # REPOPKG=$(${PACMAN_EXEC} -Fs $(echo $n | awk '{print $NF}' FS=/) | sed '1!d' | awk -F '[/ ]' '{print $2}')

              # if [[ -z ${PKG} ]]; then
                # PKG="${red}N/A${reset}"
              # fi

              NOTFOUNDFILES=$( (set -x; ldd "${n}" |grep -i "not found") |& grep -E "=> not found" | sed 's/ => not found//g; s/\s//g' | tr '\n' ' ' | sed 's/.*warning.*//g; /^\s*$/d')

              printf "\n %s %s\n" "${red}=>${reset} Missing or broken dependencies for" "${yellow}$LDDCMD_FILE${reset}"
              printf " %-38s%s\n" "   Owned by system package:" "$(${PACMAN_EXEC} -Qo "${n}" | sed 's/.* by //g')"

              # if [[ ! $MAINPKG == *"N/A"* ]] || [[ ! -z "${NIPKG}" ]]; then

                # printf " %-38s%s\n" "   Provided by..."
                # if [[ ! $MAINPKG == *"N/A"* ]]; then
                  # printf " %-38s%s\n" "   ...installed repo package(s):" "$MAINPKG"
                # fi

              if [[ ! -z "${NIPKG}" ]]; then
                printf " %-38s%s\n" "   Provided by package(s):" "${NIPKG[*]}"
                # printf " %-38s%s\n" "   ...non-installed repo package(s):" "${NIPKG[*]}"
              fi
              # fi
              printf "\n"

              # Set up a new array for r variables (libary files) and store printf output there.
              # This is just so that we don't need to check these library files again but instead
              # we can use a stored value. This is just to speed up processing.
              # TODO does this really work?

              r_count=0
              typeset -A RLIST

              for r in $(echo ${NOTFOUNDFILES[@]}); do

                if [[ ! ${RLIST[$r_count]} ]]; then
                  checklocaldirs "${MAINPKGDIRS[*]}" $r #$r_basename

                  if [[ -z ${PKG} ]]; then
                    checklocaldirs "${LOCALDIRS[*]}" $r #$r_basename
                  fi

                  LIBPKG=$PKG
                  RLIST[$r_count]=$(printf " %-47s%-30s%s\n" "   ${red}Depends on${reset}:" "$r" "${blue}Provided by${reset}: $LIBPKG")

                fi

                echo "${RLIST[$r_count]}"

                # unset MAINPKG
                # unset PKG

                # r_basename=$(echo $r | sed "s/[-0-9.]*$//") # libicui18n.so.58.4 -> libicui18n.so
                # unset PKG

                # if [[ -z ${PKG} ]]; then
                  # checkrepopkgs $r_basename
                  # if [[ -z ${PKG} ]]; then
                    # PKG="${red}N/A${reset}"
                  # fi
                # fi

                # check_main $r_basename
                # checkrepopkgs $r_basename $r

                # if [[ -z ${PKG} ]]; then
                  # PKG="N/A"
                # fi

                # for r_providers in $(${PACMAN_EXEC} -Fs $r_basename | sed '2~2d' | awk -F '[/ ]' '{print $2}'); do
                  # TODO

                  # LIBPKG[0]=$(${PACMAN_EXEC} -Fs $(echo $r | awk '{print $NF}' FS=/) | sed '1!d' | awk -F '[/ ]' '{print $2}')
                  # LIBPKG=$(${PACMAN_EXEC} -Fs $(echo $r | awk '{print $NF}' FS=/) | sed '1!d' | awk -F '[/ ]' '{print $2}')
                  # LIBPKG=$(${PACMAN_EXEC} -Fs $r | sed '1!d' | awk -F '[/ ]' '{print $2}')
                  # if [[ "${#LIBPKG[@]}" -eq 0 ]]; then

                  # if [[ $(echo $LIBPKG | wc -w) -eq 0 ]]; then
                    # LIBPKG="N/A"
                  # fi

                  # printf " %-47s%-30s%s\n" "   ${red}Depends on${reset}:" "$r" "${blue}Provided by${reset}: $LIBPKG"

                  # unset LIBPKG
                  # unset PKG
                  # unset MAINPKG

                let r_count++
              done

              unset RLIST

            fi
          done
          unset MIMEFILES #Unset MIMEFILES array for the next dependency check
        else
          printf '%s\n' "${CHECKEDLIST[$i]}"
        fi
      done
    else
      echo -e "\n No dependencies for this package."
    fi

    if [[ ! -z "${NOTFOUNDS}" ]] || [[ $LIBNOTFOUND != true ]]; then
      echo -e "\n ${green}=>${reset} Dependencies checked. All ${green}OK${reset}.\n"
    else
      echo -e "\n ${red}=>${reset} Dependency problems discovered. See above messages for details.\n"
    fi
    unset NOTFOUNDS
    unset LIBNOTFOUND

  fi
  let curpkgcount++
done
