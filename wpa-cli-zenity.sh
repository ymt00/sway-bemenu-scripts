#!/usr/bin/env bash

__STATUS_SSID=""
__SELECTED_SSID=""
__BSSIDS=""

declare -A __LIST_NETWORKS_MAP
# __REGEX_SCAN_RESULTS='^([0-9a-z\:?]{17})\s([0-9]*)\s(-[0-9]*)\s(\[.*]\]*)\s(.*)$'
__REGEX_SCAN_RESULTS='^(.*)\s(.*)\s(.*)\s(\[.*]\]*)\s(.*)$'

function showScanProgress () {
    zenity --progress \
        --title="Scanning wifi networks" \
        --text="" \
        --width="320" --height="60" \
        --no-cancel \
        --percentage=0 \
        --auto-close \
        --auto-kill
}

function showNetworksList () {
    while true; do scanResults; sleep 2; done | zenity --list \
        --title="Wifi networks" \
        --text="" \
        --width="960" --height="540" \
        --column="SSID" --column="" --column="Flags" --column="Frequency"
}

function showNetworkPassword () {
    zenity --password --title="Wifi password for $__SELECTED_SSID"
}

function scanNetworks () {
    sudo wpa_cli scan
    for i in {1..100}; do
        echo "$i"
        sleep 0.025
    done
}

function setStatus () {
    SSID=$(sudo wpa_cli status | grep "^ssid" | sed 's/ssid=//')
    if [[ $SSID != "" ]]; then
        __STATUS_SSID=$SSID
    else
        __STATUS_SSID=""
    fi
}

function setListNetworksMap () {
    REGEX_LIST_NETWORK='^([0-9]*)\s(.*)\sany\s(\[[A-Z]*\]){0,1}$'
    LIST_NETWORKS=$(sudo wpa_cli list_networks | tail -n "+3")
    IFS=$'\n'
    # Map the list networks that are already saved
    for n in $LIST_NETWORKS; do
        if [[ $n =~ $REGEX_LIST_NETWORK ]]; then
            NETWORK_ID=${BASH_REMATCH[1]}
            SSID=${BASH_REMATCH[2]}
            __LIST_NETWORKS_MAP["$SSID"]="$NETWORK_ID"
        fi
    done
    unset IFS
}

function scanResults () {
    SCAN_RESULTS=$(sudo wpa_cli scan_results | tail -n "+3")
    
    SCAN_RESULS_LIST=""
    IFS=$'\n'
    for w in $SCAN_RESULTS; do
        if [[ $w =~ $__REGEX_SCAN_RESULTS ]]; then
            BSSID="${BASH_REMATCH[1]}"
            if ! echo "$__BSSIDS" | grep -q "$BSSID"; then
                __BSSIDS="$__BSSIDS $BSSID"
                FREQUENCY="${BASH_REMATCH[2]}"
                FREQUENCY="${FREQUENCY:0:1}.${FREQUENCY:1:1}Ghz"
                FLAGS="${BASH_REMATCH[4]}"
                SSID="${BASH_REMATCH[5]}"
                SELECTED=" "
                
                if [[ "$SSID" == "$__STATUS_SSID" ]]; then
                    SELECTED=""
                fi
                if [[ $SCAN_RESULS_LIST == "" ]]; then
                    SCAN_RESULS_LIST="${SSID}\n${SELECTED}\n${FLAGS}\n${FREQUENCY}"
                else
                    SCAN_RESULS_LIST="${SCAN_RESULS_LIST}\n${SSID}\n${SELECTED}\n${FLAGS}\n${FREQUENCY}"
                fi
            fi
        fi
    done
    unset IFS
    
    echo -e "$SCAN_RESULS_LIST"

    # this make zenity bugs
    # apparently, we need to return something even an empty string
    # if [[ $SCAN_RESULS_LIST != "" ]]; then
    #     echo -e "$SCAN_RESULS_LIST"
    # else
    #     echo ""
    # fi
}

function connectNetwork () {
        NETWORK_PSK=$(wpa_passphrase "$__SELECTED_SSID" "$1" | tail -n2 | head -n1 | cut -d"=" -f2)
        NETWORK_ID=$(sudo wpa_cli add_network | tail -n 1)

        sudo wpa_cli set_network "$NETWORK_ID" ssid "\"$__SELECTED_SSID\"" && \
        sudo wpa_cli set_network "$NETWORK_ID" psk "$NETWORK_PSK" && \
        sudo wpa_cli enable_network "$NETWORK_ID" && \
        sudo wpa_cli save_config
}

function selectNetwork () {
    sudo wpa_cli select_network "$1"
}

setListNetworksMap

setStatus

scanNetworks | showScanProgress

__SELECTED_SSID="$(showNetworksList)"

case $? in
    0)
    if [[ "$__SELECTED_SSID" != "" ]] && [[ "$__SELECTED_SSID" != "$__STATUS_SSID" ]]; then
        NETWORK_ID=${__LIST_NETWORKS_MAP["$__SELECTED_SSID"]}
        if [[ -z "$NETWORK_ID" ]]; then
            NETWORK_PWD="$(showNetworkPassword)"
            case $? in
                0)
                connectNetwork "$NETWORK_PWD"
                ;;
                # 1)
                # echo "PASSWORD CANCELED BY USER"
                # ;;
                # -1)
                # echo "PASSWORD ERROR"
                # ;;
            esac
        else
            # the network is already saved
            selectNetwork "$NETWORK_ID"
        fi
    # else
    #     echo "Already connected to $__SELECTED_SSID or Wifi not set"
    fi
    ;;
    # 1)
    # echo "WIFI SELECTION CANCELED BY USER"
    # ;;
    # -1)
    # echo "WIFI SELECTION ERROR"
    # ;;
esac
