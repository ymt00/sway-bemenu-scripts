#!/usr/bin/env bash

__STATUS_BSSID=""
__SELECTED_SSID=""
__BSSIDS=""

declare -A __LIST_NETWORKS_MAP
__REGEX_SCAN_RESULTS='^(.*)\s(.*)\s(.*)\s(\[.*]\]*)\s(.*)$'
__REGEX_LIST_NETWORK='^([0-9]*)\s.*\s(.*)\s(\[[A-Z]*\]){0,1}$'

function showNetworksList() {
    while true; do
        TEST_PROC=$(ps ax | grep -c "yad --list --name=wpa_cli floating 960x540")
        if [[ $TEST_PROC -lt 2 ]]; then break; fi
        
        scanResults
        sleep 0.5
    done | yad --list \
        --name="wpa_cli floating 960x540" \
        --title="Wifi networks" \
        --text="" \
        --width="960" --height="540" \
        --column="" --column="SSID" --column="Flags" --column="Frequency" --column="BSSID" \
        --hide-column=5 \
        --print-column=0 \
        --search-column=2
}

function showNetworkPassword() {
    yad --entry \
        --entry-label="Mot-de-passe" \
        --name="wpa_cli floating 320x60" \
        --hide-text \
        --title="Wifi password for $__SELECTED_SSID"
}

function scanNetworks() {
    sudo wpa_cli scan
}

function setStatus() {
    BSSID=$(sudo wpa_cli status | grep "^bssid" | sed 's/bssid=//')
    if [[ $BSSID != "" ]]; then
        __STATUS_BSSID=$BSSID
    else
        __STATUS_BSSID=""
    fi
}

function setListNetworksMap() {
    LIST_NETWORKS=$(sudo wpa_cli list_networks | tail -n "+3")
    IFS=$'\n'
    # Map the list networks that are already saved
    for n in $LIST_NETWORKS; do
        if [[ $n =~ $__REGEX_LIST_NETWORK ]]; then
            NETWORK_ID=${BASH_REMATCH[1]}
            BSSID=${BASH_REMATCH[2]}
            __LIST_NETWORKS_MAP["$BSSID"]="$NETWORK_ID"
        fi
    done
    unset IFS
}

function scanResults() {
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

                if [[ "$BSSID" == "$__STATUS_BSSID" ]]; then
                    SELECTED=""
                fi
                if [[ $SCAN_RESULS_LIST == "" ]]; then
                    SCAN_RESULS_LIST="${SELECTED}\n${SSID}\n${FLAGS}\n${FREQUENCY}\n${BSSID}"
                else
                    SCAN_RESULS_LIST="${SCAN_RESULS_LIST}\n${SELECTED}\n${SSID}\n${FLAGS}\n${FREQUENCY}\n${BSSID}"
                fi
            fi
        fi
    done
    unset IFS

    if [[ $SCAN_RESULS_LIST != "" ]]; then
        echo -e "$SCAN_RESULS_LIST"
    else
        echo -n ""
    fi
}

function connectNetwork() {
    NETWORK_PSK=$(wpa_passphrase "$__SELECTED_SSID" "$1" | tail -n2 | head -n1 | cut -d"=" -f2)
    NETWORK_ID=$(sudo wpa_cli add_network | tail -n 1)

    sudo wpa_cli set_network "$NETWORK_ID" ssid "\"$__SELECTED_SSID\"" &&
        sudo wpa_cli set_network "$NETWORK_ID" psk "$NETWORK_PSK" &&
        sudo wpa_cli bssid "$NETWORK_ID" "$__SELECTED_BSSID" &&
        sudo wpa_cli enable_network "$NETWORK_ID" &&
        sudo wpa_cli save_config
}

function selectNetwork() {
    sudo wpa_cli select_network "$1"
}

setListNetworksMap

setStatus

scanNetworks

__SELECTED_NETWORK="$(showNetworksList)"
case $? in
0)
    __SELECTED_NETWORK=$(echo "$__SELECTED_NETWORK" | cut -d"|" -f2,5)
    __SELECTED_SSID=$(echo "$__SELECTED_NETWORK" | cut -d"|" -f 1)
    __SELECTED_BSSID=$(echo "$__SELECTED_NETWORK" | cut -d"|" -f 2)
    if [[ "$__SELECTED_SSID" != "" ]] && [[ "$__SELECTED_BSSID" != "" ]] && [[ "$__SELECTED_BSSID" != "$__STATUS_BSSID" ]]; then
        NETWORK_ID=${__LIST_NETWORKS_MAP["$__SELECTED_BSSID"]}
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
