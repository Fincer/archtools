#!/bin/bash

##################################################
# Search package in online repositories

if [ -z "$1" ] ; then
    echo "Usage: findpkg <string>"
    return 1
else
#
# pacman: find packages which include/refer to user input string $1 by using online repositories. Verbose order
#
# Sort the output: 
# 1) sed: remove first 9 lines 
# 2) sed: remove everything before the first slash in every other line (package names), including the slash itself
# 3) sed: remove version number strings in every other line (all numbers after the first space after package names
# 4) sed: remove bracket mark ) from every other line
# 5) perl: colorize the output: every other line with bold blue ( \033[1:34m ) and the other after that with dim yellow ( \033[0;33m ). Starting from the first output line (sorted by sed in the first step)
# 6) sed: colorize all '[installed]' strings with bold red ( [ \033[1;31m )
# 7) echo: normalize bash text (reset colors with \e[0m)
# NOTE: \e and \033 mean the same thing.
# NOTE: More bash colors here: http://misc.flogisoft.com/bash/tip_colors_and_formatting
#

    pacman -Ssv $1 | sed -e '1,9d' | sed -e '1~2s/^.*\///' -e '1~2s/ .*[0-9]//g' -e '1~2s/)//g' | perl -pe '$_ = "\033[1;34m$_\033[0;33m" if($. % 2)' | sed ''/\\[installed\\]/s//$(printf "\033[1;31m\\[installed\\]")/''
fi
echo -e '\e[0m'
