#!/bin/bash

###########################################################
# Grep/List matching strings in a specific folder

if [ -z "$1" ]; then
    $1=/ #If folder not specified, then we use root folder as a starting path
fi

if [ -z "$2" ]; then #If string not defined, then...
    # display usage if no string is given
    echo "Usage: findmatch <folder_path> <string>"
    return 1
else
    ls $1 |grep -i "$2"
fi
