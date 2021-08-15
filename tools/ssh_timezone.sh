#!/usr/bin/env bash
#
#    SSH timezone - Automatically retrieve timezone information for SSH users
#
#    Copyright (C) 2018  Pekka Helenius
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.

#####################################

# This script is meant to be used as a part of provided 'bash.custom' file

#####################################

REQ_PKGS=(geoip2-database mmdblookup systemd openssh bind-tools)
PACMAN_EXEC="/usr/bin/pacman"

for pkg in ${REQ_PKGS[*]}; do
    if [[ ! $("${PACMAN_EXEC}" -Q | grep $pkg) ]]; then
        echo -e "\nMissing package $pkg\n"
        kill -INT $$
    fi
done

GEOIP2_DATABASE="/usr/share/GeoIP/GeoLite2-City.mmdb"

if [[ ! -f $GEOIP2_DATABASE ]]; then

    # GeoIP2 database file couldn't be found
    kill -INT $$

fi

# If SSH_CONNECTION variable is defined
if [[ $(export -p | grep -o SSH_CONNECTION) ]]; then

    # Get IP address of the user
    RUSER_IP=$(echo $SSH_CONNECTION | awk '{print $1}')

    # If SSH IP is local, try to get public IP.
    if [[ $RUSER_IP =~ ^192\.168\. ]] || [[  $RUSER_IP =~ ^10\. ]] || [[ $USER_IP =~ ^172\.{16..31}\. ]]; then

        RUSER_WAN_IP=$(dig +short +time=8 +tries=1 myip.opendns.com @resolver1.opendns.com 2>/dev/null)

        # If OpenDNS hostname can't be resolved, use local IP as a fallback
        if [[ $(echo $RUSER_WAN_IP | wc -w) -eq 0 ]]; then
            RUSER_WAN_IP=$RUSER_IP
        fi
    else

        # WAN IP is used IP
        RUSER_WAN_IP=$RUSER_IP
    fi
else

    # Couldn't find IP address from SSH_CONNECTION variable
    kill -INT $$
fi

TZ=$(mmdblookup -f $GEOIP2_DATABASE -i $RUSER_WAN_IP location 2>/dev/null | awk '/time_zone/ {getline; print $0}' | awk -F '"' '{print $2}')

# If TZ is empty, then use server default time zone setting as a default value
if [[ $(echo $TZ | wc -w) -eq 0 ]]; then
    export TZ=$(timedatectl | sed '/Time zone:/!d' | awk '{print $3}')
else
    export TZ
fi
