#!/bin/bash

##################################################

# Find a string in package files (Arch Linux)
#
# Usage:

# bash ./findstr.sh <executable name> <searchable string>
#
# For example:
#
# bash ./findstr.sh makepkg E_USER_FUNCTION_FAILED

##################################################

for file in $(pacman -Ql $(pacman -Qo $(which "${1}") | awk '{print $($NF)}') | awk '{print $2}' | sed '/\/$/d'); do 
    grep -ril "{2}" ${file}
done
