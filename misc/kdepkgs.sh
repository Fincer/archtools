#!/bin/env bash
# Simple core KDE package finder on Arch Linux
# Pekka Helenius, 2018

pattern="https://community.kde.org/Frameworks"

IFS=$'\n'
for pkg in $(pacman -Q | awk '{print $1}'); do
    if [[ $(printf $(pacman -Qi $pkg | grep -E ${pattern} &> /dev/null)$?) -eq 0 ]]; then
        echo $pkg
    fi
done
unset IFS
