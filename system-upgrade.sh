#!/usr/bin/env sh

if swaymsg -rt get_tree | grep '"app_id": "system-upgrade'
then
    sway [app_id='system-upgrade'] focus
else
    foot -T 'System upgrade' -a 'system-upgrade floating 1460x920 border' \
        /home/yves/Scripts/zsh/system-upgrade.sh
fi

