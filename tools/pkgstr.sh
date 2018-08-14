#!/bin/bash

###########################################################
# Search a text pattern inside package files
read -r -p "Enter search pattern: " TEXT

if [[ -z $TEXT ]]; then
    echo -e "\nInvalid input\n"
    exit
else

    for p in $(echo "${@}"); do

    echo -e " \033[1m\033[92m=>\033[39m\033[0m Files of package '$p' containing pattern '$TEXT':\n"

        for i in $(pacman -Ql $p | awk -F ' ' '{print $NF}' | sed '/\/*.*\/$/d'); do 
            sudo grep -Ril "$TEXT" $i
        done
    done
fi
