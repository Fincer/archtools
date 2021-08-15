#!/usr/bin/env bash
#
#   nowner - Find orphan files on various Linux distributions
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

bash_yellow=$'\033[93m'
bash_red=$'\033[91m'
bash_color_default=$'\033[0m'

PACMAN_EXEC="/usr/bin/pacman"

#####################################

#Useful for additional commands:

# TODO: Look for .old .bak ~ .pacnew and such files (maybe separate command or not??)

#find /usr/share -maxdepth 1 -type d -exec stat --format "%n: %U" {} \; | grep fincer

#####################################
# Check for command dependencies

if [[ $(which --help 2>/dev/null) ]] && [[ $(echo --help 2>/dev/null) ]]; then

    COMMANDS=(who awk getent printenv sed file stat id date find tee chown timedatectl hostname)

    a=0
    for command in ${COMMANDS[@]}; do
        if [[ ! $(which $command 2>/dev/null) ]]; then
            COMMANDS_NOTFOUND[$a]=$command
            let a++
        fi
    done

    if [[ -n $COMMANDS_NOTFOUND ]]; then
        echo -e "\n${bash_red}Error:${bash_color_default} The following commands could not be found: ${COMMANDS_NOTFOUND[*]}\nAborting\ņ"
        exit 1
    fi
else
    exit 1
fi

#####################################
# Retrieve our Linux distribution and set the correct
# package manager for this command

# Get our Linux distribution
DISTRO=$(cat /etc/os-release | sed -n '/PRETTY_NAME/p' | grep -o '".*"' | sed -e 's/"//g' -e s/'([^)]*)'/''/g -e 's/ .*//' -e 's/[ \t]*$//')

function check_pkgmgr() {

    if [[ ! $(which $1 2>/dev/null) ]]; then
        echo -e "\n${bash_red}Error:${bash_color_default} Package manager ($1) could not be found\nAborting\ņ"
        exit 1
    fi
}

#####################################

# Arch Linux
if [[ $DISTRO == "Arch" ]]; then
    check_pkgmgr pacman
    function PKGMGR_CMD() { ${PACMAN_EXEC} -Qo "$1" &>/dev/null || echo "error" | wc -l ; }
fi

# Debian, Ubuntu
if [[ $DISTRO == "Ubuntu" ]] || [[ $DISTRO == "Debian" ]]; then
    check_pkgmgr dpkg
    function PKGMGR_CMD() { dpkg -S "$1" &>/dev/null || echo "no path found matching pattern" | wc -l ; }
fi

# CentOS
# TODO

# Fedora
# TODO

# RedHat
# TODO

# OpenSUSE
# TODO

#####################################
# List files and directories which are not owned by any package in the system
echo -e "\nSearch for files & folders which are not owned by any installed package.\n"

# Avoid storing log files into root home
REAL_USER=$(who am i | awk '{print $1}')
REAL_USER_HOME=$(getent passwd $REAL_USER | cut -d: -f6)

if [[ $# -eq 0 ]]; then
    read -r -p "Folder path: " BASEDIR
    #Substitute $ symbol from environmental variables for printenv input
    if [[ $BASEDIR == *"$"* ]]; then
        BASEDIR=$(echo $(printenv $(echo ${BASEDIR} | sed 's/\$//g')))
    fi
else
    BASEDIR=$1
fi

if [[ ! $(file --mime-type "${BASEDIR}" | grep "inode/directory" | wc -l) -eq 1 ]]; then
    echo "${bash_red}Error:${bash_color_default} Use full folder path as an input value!"
elif [[ $# -gt 1 ]]; then
    echo "${bash_red}Error:${bash_color_default} Only one argument accepted!"
else

    echo -e "Search depth:\n1 = "${BASEDIR}"\n2 = "${BASEDIR}" & subfolders\n3 = "${BASEDIR}", subfolders & 2 folder levels below\n4 = no limit\n"
    read -r -p "Which depth value you prefer? [Default: 1] " response

    case $response in
        1)
            depth="-maxdepth 1 "
            depthstr="${BASEDIR}"
            DEPTH_NUM=1
            ;;
        2)
            depth="-maxdepth 2 "
            depthstr="${BASEDIR} and subfolders"
            DEPTH_NUM=2
            ;;
        3)
            depth="-maxdepth 3 "
            depthstr="${BASEDIR}, subfolders and 2 folder levels below"
            DEPTH_NUM=3
            ;;
        4)
            depth=""
            depthstr="${BASEDIR} and all subfolders"
            DEPTH_NUM=4
            ;;
        *)
            echo -e "\nUsing default value [1]"
            depth="-maxdepth 1 "
            depthstr="${BASEDIR}"
            DEPTH_NUM=1
    esac

    unset response

#####################################

    BASEDIR_OWNER=$(stat --format "%u" "${BASEDIR}")

    if [[ $BASEDIR_OWNER -eq 0 ]] && [[ $(id -u) -ne 0 ]]; then
        echo -e "\n${bash_yellow}Warning:${bash_color_default} the main folder '${BASEDIR}' is owned by root. Some files or directories may be inaccessible. Please consider running this command with root privileges.\n"

        read -r -p "Continue? [Y/n] " response
        if [[ $(echo $response | sed 's/ //g') =~ ^([nN][oO]|[nN])$ ]]; then
            echo -e "\nAborting\n"
            exit 0
        fi

    elif [[ $BASEDIR_OWNER -ne $(id -u $REAL_USER) ]] && [[ $BASEDIR_OWNER -ne 0 ]]; then
        echo -e "\n${bash_yellow}Warning:${bash_color_default} the main folder belongs to local user '$(id -un $BASEDIR_OWNER)'. Some files or directories may be inaccessible\n"
    fi

#####################################

    BASEDIR_UNDERLINE="$(echo ${BASEDIR} | sed 's/\//_/g')"
    LOGFILE="$REAL_USER_HOME/nowner-${BASEDIR_UNDERLINE}-depth-${DEPTH_NUM}_$(date +%Y-%m-%d).log"

    # Delete log file if the command is interrupted
    # Define function del_log here, after we have defined $LOGFILE
    #
    # Interrupt signal must be trapped after $LOGFILE and before any further commands
    # That's why it is located here and not at the end or at the start of this script
    #
    del_log() { rm $LOGFILE ; exit 0 ; }
    trap 'del_log' INT

    read -r -p "Save results to a file? [Y/n] " response
        if [[ $(echo $response | sed 's/ //g') =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo -e "Scan results will be saved in '$LOGFILE'"
            TO_FILE=1
        else
            TO_FILE=0
        fi

#####################################

    echo -e "\nSearching unowned files & folders in $depthstr\n"

#####################################

    function data_counter() {
        i=0
        n=1
        ARRAY=("$@")
        COUNT=${#ARRAY[@]}

        for scan_data in "${ARRAY[@]}"; do

            echo -ne "Scanning $data_name $n ($(( 100*$n/$COUNT ))%) of all $type ($COUNT) in $depthstr\r"

            if [[ $(PKGMGR_CMD $scan_data) -eq 1 ]]; then
                DATA_ARRAY[$i]="$(( $i + 1 )) - ${scan_data}"
                let i++
            fi
            let n++

        done

###############

        function results() {

            if [[ $i -gt 0 ]]; then
                echo -e "\nThe following $i of $COUNT $type is not owned by any installed package in $depthstr:\n"
                IFS=$'\n'
                echo -e "${DATA_ARRAY[*]}\n"
                unset IFS
                unset DATA_ARRAY
            elif [[ "$COUNT" -eq 0 ]]; then
                echo -e "\nCouldn't find any $type in the target path $depthstr. Consider using greater depth value.\n"
            else
                echo -e "\nAll $type are owned by system packages in $depthstr"
            fi
        }

        if [[ $TO_FILE -eq 1 ]]; then
            results | tee -a $LOGFILE
            echo ""
        else
            results
            echo ""
        fi

    }

#####################################

    function data_check() {

        DATASET=$(find "${BASEDIR}" ${depth} ${1} 2>/dev/null)

        IFS=$'\n'
        datacnt=0
        for DATA in ${DATASET}; do

            # Do read permission check for files/folders unless we are root
            #
            if [[ $(id -u) -ne 0 ]]; then

                echo -e "Checking for $2 permissions. Please wait\n"

                DATA_OWNER=$(stat --format "%u" "${DATA}")
                DATA_OWNER_HUMAN=$(stat --format "%U" "${DATA}")

                # If the current user (which this command is executed by) is not the owner of folder/file
                # By performing this check we can distinguish whether the user
                # belongs to the owner class or "others" class
                # and therefore we can perform check for "read" bit
                # for "others" if needed
                #
                if [[ $(id -u) -ne $DATA_OWNER ]]; then

                    # If read bit is defined for "others"
                    if [[ $(stat --format "%A" "${DATA}" | cut -c 8) == "r" ]]; then
                        VALID_DATASET[$datacnt]="${DATA}"
                        let datacnt++
                    else
                        echo -e "${bash_yellow}Warning:${bash_color_default} $data_name '${DATA}' (owned by $DATA_OWNER_HUMAN) is not readable. Skipping it\n"
                    fi

                # We assume that the file/dir owner has read permission for this specific file/folder
                #
                else #elif [[ $(id -u $REAL_USER) -eq $DATA_OWNER ]]; then
                    VALID_DATASET[$datacnt]="${DATA}"
                    let datacnt++
                fi
            else
                VALID_DATASET[$datacnt]="${DATA}"
                let datacnt++
            fi
        done
        unset IFS
        unset datacnt
        data_counter "${VALID_DATASET[@]}"
        unset VALID_DATASET
    }

#####################################

    function folders() {
        type="folders"
        data_name="folder"
        find_type="-mindepth 1 -type d"
        data_check "${find_type}" $data_name
    }

    function files() {
        type="files"
        data_name="file"
        find_type="-type f"
        data_check "${find_type}" $data_name
    }

#####################################

    if [[ $TO_FILE -eq 1 ]]; then
        echo -e "Log timestamp: $(date '+%d-%m-%Y, %X') (TZ: $(timedatectl status | grep "Time zone:" | awk '{print $3}'))\nComputer: $(hostname)\nScanning Depth: $depthstr" >> $LOGFILE
    fi

    folders
    files

    if [[ $TO_FILE -eq 1 ]]; then
        chown $REAL_USER $LOGFILE
        echo -e "Scan complete. Results have been saved in '$LOGFILE'\n"
    else
        echo -e "Scan complete\n"
    fi

fi
