#!/bin/bash

#####################################
# Show information about executable on Arch Linux
BIN=$(which $1)
echo -e "$BIN\n$(pacman -Qo $BIN)"
