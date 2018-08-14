#!/bin/bash

# Randomize MAC Address
trap ctrl_c INT

function ctrl_c() {
        echo -e "\nAborting.\n"
        return
}

random_mac() {
    MAC=$(printf '%02x' $((0x$(od /dev/urandom -N1 -t x1 -An | cut -c 2-) & 0xFE | 0x02)); od /dev/urandom -N5 -t x1 -An | sed 's/ /:/g')
}

insert_mac() {
    echo -e "\nChanging MAC address information (root permission required).\n"
    
    sudo sed -i "/\[Link\]/!b;n;cMACAddress=$MAC" /etc/systemd/network/00-default.link
    echo -e "MAC address changed from '$MAC_OLD' to '$MAC' for interface '$MAC_DEVICE'.\n\nPlease restart this interface to apply the changes.\n\nTo restore original MAC address, either delete configuration file '/etc/systemd/network/$linkname' or set real MAC address manually into it.\n"
    return 0
}

geninsert_mac() {

    gennew_mac() {
    
        while true; do
            unset response
            read -r -p "Generate a new MAC address? [Y/n] " response
            
            if [[ $(echo $response | sed 's/ //g') =~ ^([yY][eE][sS]|[yY])$ ]]; then
                random_mac
                newname_mac
            else
                echo -e "\nKeeping old MAC address configuration.\n"
                return
            fi
        done
    }

    newname_mac() {
        unset response
        read -r -p "New MAC address for '$MAC_DEVICE' will be '$MAC'. Accept? [Y/n] " response
    
        if [[ $(echo $response | sed 's/ //g') =~ ^([yY][eE][sS]|[yY])$ ]]; then
            insert_mac
        else
            gennew_mac
        fi
    }
    newname_mac
}

gen_mac() {

    real_mac() {

        AVAILABLE_MACS=$(ip -br link show | sed '/LOOPBACK/d' | awk '{print NR"\t"$1"\t"$3"\t"$2}')
        
        IFS=$'\n'

        echo -e "\nAvailable network interfaces with their MAC addresses are:\n\n${AVAILABLE_MACS[*]}"
        
        echo -e "\nPlease select the interface which MAC address you want to spoof of\n"
        read -r -p "Selection [number]: " number
        
        if [[ ! $number =~ ^[0-9]+$ ]]; then
            echo -e "\nInvalid input value. Aborting.\n"
            return 1
        fi
        
        for INTERFACE in $(echo -e "${AVAILABLE_MACS[*]}"); do
        
            intf_num=$(echo $INTERFACE | awk '{print $1}')

            if [[ $number -eq $intf_num ]]; then
                MAC_REAL=$(echo $INTERFACE | awk '{print $3}')
                MAC_DEVICE=$(echo $INTERFACE | awk '{print $2}')
                break
            fi
        done
        unset IFS

        if [[ $MAC_REAL == "" ]]; then
            echo -e "\nNot a valid MAC address found for interface number $number. Aborting.\n"
            return 1
        fi

    }

    real_mac

    PREV_CONF=$(grep -Ril "$MAC_REAL" /etc/systemd/network/)
    
    if [[ ! $(echo $PREV_CONF | wc -w) -eq 0 ]]; then 
        echo -e "\nUsing existing configuration file for interface '$MAC_DEVICE':\n$PREV_CONF\n"
        linkname=$(basename $PREV_CONF)
        MAC_OLD=$(awk -F= '/\[Link\]/{getline; print $2}' $PREV_CONF)
    else
        MAC_OLD=$MAC_REAL
        echo -e "\nPrevious configuration file not found. Creating it (root permission required).\n"
        read -r -p "Configuration file name? (must follow syntax: 00-default.link, 41-default.link, 98-default.link etc.): " linkname

        if [[ $linkname =~ ^[0-9][0-9]-default.link ]]; then
        
            if [[ ! $(sudo -n true) ]]; then
                sudo echo ""
            fi
        
            echo -e "[Match]\nMACAddress=$MAC_REAL\n\n[Link]\nMACAddress=$MAC_REAL\nNamePolicy=kernel database onboard slot path" \
            | sudo tee /etc/systemd/network/$linkname > /dev/null
            
            echo -e "Created new configuration file: /etc/systemd/network/$linkname\n"
        else
            echo -e "\nInvalid file name given. Aborting.\n"
            return 1
        fi
    fi

    unset response
    echo -e "Either randomly generated or manually specified MAC address can be used.\n"
    read -r -p "Do you want to use randomly generated MAC address? [Y/n] " response

    if [[ $(echo $response | sed 's/ //g') =~ ^([yY][eE][sS]|[yY])$ ]]; then
        random_mac
        geninsert_mac
    else
    
        if [[ $(echo $response | sed 's/ //g') =~ ^([nN][oO]|[nN])$ ]]; then
            read -r -p "Please type a new MAC address (Syntax is e.g. aa:bb:33:zz:f0:4a): " MAC
            maxtries=5
            while [[ $maxtries -gt 0 ]]; do

                case "$MAC" in 
                [[:xdigit:]][[:xdigit:]]:[[:xdigit:]][[:xdigit:]]:[[:xdigit:]][[:xdigit:]]:[[:xdigit:]][[:xdigit:]]:[[:xdigit:]][[:xdigit:]]:[[:xdigit:]][[:xdigit:]])
                    insert_mac
                    ;;
                esac
                unset MAC
                read -r -p "Invalid MAC address given. Please type again ($maxtries tries left): " MAC
                let maxtries--
            done
        else
            echo -e "\nInvalid answer. Aborting.\n"
        fi
    fi
}

echo -e "\nWARNING: Changing MAC address WILL DISRUPT connections to any network device using MAC-based authentication methods. These devices may include configured routers, WiFi hotspots etc. Remember to write down the new MAC address, and make sure you are authorized to configure the MAC address to all affected network devices if needed.\n"
read -r -p "You are going to spoof a MAC address of a network interface of this computer. Are you sure? [Y/n] " response

if [[ $(echo $response | sed 's/ //g') =~ ^([yY][eE][sS]|[yY])$ ]]; then
    gen_mac
else
    echo -e "\nKeeping old MAC address configuration.\n"
fi
