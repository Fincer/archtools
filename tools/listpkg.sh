#!/bin/bash

###########################################################
# Show packages named as <input> on Arch Linux
pacman -Q | grep "$1" | cut -d' ' -f1
