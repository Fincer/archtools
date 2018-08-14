#!/bin/bash

###########################################################
# Show specific package, installed and available version
echo ""
PKGMGR="pacman"

for p in $(echo "${@}"); do
  
    INSTALLDATE=$($PKGMGR -Qi $p | grep "Install Date" | awk -F ': ' '{print $2}')
    NEWDATE=$($PKGMGR -Si $p | grep "Build Date" | awk -F ': ' '{print $2}')
    echo "Installed: $($PKGMGR -Q $p) ($INSTALLDATE)"
    echo $($PKGMGR -Si $p | grep -E "Version.*:|Build Date.*:" | awk -F ': ' '{print $2}') | awk -v pkg=$p -F ' ' '{print "Available: " pkg " " $1 " ("substr($0,length($1)+1)")"}' | sed 's/( /(/g'
    echo ""
    #echo -e "Available: $p $($PKGMGR -Si $p | grep "Version.*:" | awk -F ' ' '{print $3}')\n"
done
