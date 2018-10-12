#!/bin/bash

#    getsource - Get build files for Arch/AUR packages on Arch Linux
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

###########################################################

# TODO: Add support for wider range of processor architectures (below)
# TODO: Add directory support (getsource wine ~/winesource)
# TODO: create subdir for source files automatically to the current main dir

###########################################################

ARCH_DOMAINURL="https://git.archlinux.org"
ARCH_GITBASES=('packages.git' 'community.git')

AUR_DOMAINURL="https://aur.archlinux.org"
AUR_GITBASES=('aur.git')

CURDIR=$(pwd | awk '{print $NF}' FS=/)

if [[ -n "$1" ]]; then
    CURDIR="$1"
else
    read -r -p "Source package name? [Default: $CURDIR] " response
    if [[ -n $response ]]; then
        CURDIR=$response
    fi
fi

INPUT="${CURDIR}"

##################################

function check_database() {
    for GITBASE in ${2}; do

        if [[ "$1" != "$AUR_DOMAINURL" ]]; then
            BASEURL="$1/svntogit/$GITBASE/tree/trunk?h=packages/$CURDIR"
            DOMAINURL=$ARCH_DOMAINURL
        else
            BASEURL="$1/cgit/$GITBASE/snapshot/$CURDIR.tar.gz"
            DOMAINURL=$AUR_DOMAINURL
        fi

        wget -q -T 5 "$BASEURL" -o -
        if [[ $? -eq 0 ]]; then
            wget -q "$BASEURL"
            if [[ "$1" != "$AUR_DOMAINURL" ]]; then
                mv ./trunk?h=packages%2F$CURDIR ./baseurl.html
            else
                tar xf "$CURDIR.tar.gz"
            fi
            break
        fi
    done

    if [[ ! -f ./baseurl.html ]]; then
        return 1
    fi
}

##################################

function arch_repos_deepscan() {

    ARCH_DATABASES=(core extra community community-testing)

    for ARCH_DB in ${ARCH_DATABASES[*]}; do

        ARCH_DB_URL="https://www.archlinux.org/packages/$ARCH_DB/x86_64/$CURDIR"

        wget -q -T 10 "$ARCH_DB_URL" -o -
        if [[ $? -eq 0 ]]; then
            wget -q "$ARCH_DB_URL"
            mv ./$CURDIR ./baseurl_2.html
            break
        fi

    done

    if [[ -f baseurl_2.html ]]; then
        echo -e "Selecting another package name:\n"
        CURDIR=$(grep "Source Files" baseurl_2.html | sed "s/.*href=[\"'].*packages\///g; s/[\"'].*//g")
        echo -e "Package name is $CURDIR"
        rm baseurl_2.html
        check_database "$ARCH_DOMAINURL" "${ARCH_GITBASES[*]}"
        arch_dl_files
    else
        echo -e "\nCouldn't find package $CURDIR\n"
        exit 1
    fi

}

##################################

function arch_dl_files() {
    if [[ -f baseurl.html ]]; then
        FILELIST=$(cat baseurl.html | grep -E "ls-mode" | sed "s/.*href=[\"']//g; s/[\"']>plain.*//g")

        for file in $FILELIST; do
            if [[ ! -f $file ]]; then
                # Wget only if file doesn't exist
                wget -q $DOMAINURL/$file
                mv $(echo "$file" | sed 's/.*trunk//g; s/\///1' | sed 's/\//%2F/g') $(echo $file | sed 's/.*trunk//g; s/?.*//g; s/\///g')
            fi
        done
        rm baseurl.html
        echo -e "\nSource files for $CURDIR downloaded\n"

    elif [[ -f "$CURDIR.tar.gz" ]]; then
        mv ./$CURDIR/* ./
        rm -Rf {"$CURDIR.tar.gz",$CURDIR}
        echo -e "\nSource files for $CURDIR downloaded\n"
    else
        arch_repos_deepscan
    fi
}

##################################

check_database "$ARCH_DOMAINURL" "${ARCH_GITBASES[*]}"

if [[ ! $? -eq 0 ]]; then
    check_database "$AUR_DOMAINURL" "${AUR_GITBASES[*]}"
fi

arch_dl_files

##################################

# Check if we are raspberry pi (ARM 7) or not
if [[ $(cat /proc/cpuinfo | grep -i armv7 -m1 | wc -l) -eq 1 ]]; then
    if [[ -f PKGBUILD ]]; then
        cat PKGBUILD | grep arch= | grep -E "any|armv7h" > /dev/null
        if [[ $? -ne 0 ]]; then
            sed -i "s/arch=.*/arch=('any')/" PKGBUILD
            echo -e "Modified architecture in PKGBUILD to 'any'\n"
        fi
    fi
fi

##################################

rm -rf ./{"${INPUT}"*.1,*trunk*} 2>/dev/null
