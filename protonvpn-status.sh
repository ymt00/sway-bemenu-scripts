#!/usr/bin/env sh

if swaymsg -rt get_tree | grep '"app_id": "protonvpn'
then
    sway [app_id='protonvpn'] focus
else
    foot \
        -T "Proton VPN" \
        -a "protonvpn floating 640x320 border" \
        sh -c "protonvpn s && read -n1"
fi
