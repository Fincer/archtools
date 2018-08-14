#!/bin/bash

# Source: https://unix.stackexchange.com/questions/269077/tput-setaf-color-table-how-to-determine-color-codes

# Author: user79743

color(){
    for c; do
        printf '\e[48;5;%dm%03d' $c $c
    done
    printf '\e[0m \n'
}

IFS=$' \t\n'
color {0..15}
for ((i=0;i<6;i++)); do
    color $(seq $((i*36+16)) $((i*36+51)))
done
color {232..255}
