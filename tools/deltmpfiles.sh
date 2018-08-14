#!/bin/bash

###########################################################
# Delete current temporary files

#All tmp files currently being used
TMP_USED=$(lsof +D /tmp/ | awk '{print $9," "}' | sort -u | tail -n+3 | sed 's/[ \t]*$//')

#All tmp files
TMP_ALL=$(find /tmp/ -type s -print -o -type f -print | sort -u | sed 's/[ \t]*$//')

#Get all tmp files/symlinks/etc which are not being used at the moment
# Exclude /tmp/.X11-unix/X0 from the list
#
TMP_NOTUSED=$(comm -23 <(echo "$TMP_ALL") <(echo "$TMP_USED") | sed 's/\/tmp\/.X11-unix\/X0//g; /^\s*$/d')

echo "$TMP_NOTUSED" | while read line; do echo "Deleting file $line" && sudo rm $line ; done
