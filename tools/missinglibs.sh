#!/bin/bash

###########################################################
# Missing package libraries

ldd $(mimetype $(pacman -Ql "${1}") | grep -iE "x\-sharedlib|x\-executable" | sed 's/\:.*//g') | grep -i "not found"
