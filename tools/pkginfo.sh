#!/bin/bash

#################################
# Gather some package information with pacman on Arch Linux

FILETHRESHOLD=100

if [[ $2 == "local" ]]; then
    pacman -Qi $1
    if [[ $3 == "files" ]]; then
        if [[ $(pacman -Ql $1 | wc -l) -gt $FILETHRESHOLD ]]; then
            echo "Package $1 has $(pacman -Ql $1 | wc -l) files/dirs"
            sleep 3
            pacman -Ql $1 | less
        fi
    fi
elif [[ $2 == "remote" ]]; then
    pacman -Si $1
    if [[ $3 == "files" ]]; then
        if [[ $(pacman -Ql $1 | wc -l) -gt $FILETHRESHOLD ]]; then
            echo "Package $1 has $(pacman -Ql $1 | wc -l) files/dirs"
            sleep 3
            pacman -Ql $1 | less
        fi
    fi
else
    echo -e "Input: sh pkginfo.sh <package> [local/remote] [files]\n"
fi
