#!/usr/bin/env bash
# depends on trash-cli and zenity

TRASH="$HOME/.local/share/Trash/files/"

function trashList () {
    REGEX='^([0-9\-]*)\s([0-9:]*)\s(.*)$'
    IFS=$'\n'
    for l in $(trash-list); do
        if [[ $l =~ $REGEX ]]; then
            DATE=$(/usr/bin/date "+%a %d %b %Y" -d "${BASH_REMATCH[1]}")
            TIME=$(/usr/bin/date "+%H:%M" -d "${BASH_REMATCH[2]}")
            PATH="${BASH_REMATCH[3]}"
            ICON=""
            if [ -d "$TRASH$(/usr/bin/basename "$PATH")" ]; then
                ICON=""
            fi
            printf "%s à %s\t%s %s\n" "$DATE" "$TIME" "$ICON" "$PATH"
        fi
    done
    unset IFS
}

RESTORE=$(trashList | bemenu \
--list 40 \
--prompt " Poubelle" \
--no-exec)

if [ -n "$RESTORE" ]; then
    RESTORE=$(echo "$RESTORE" | cut -f2- | cut -d' ' -f2-)
    zenity --question --text="Etes-sûr de vouloir restaurer <b>$RESTORE</b> ?" --title="Confirmation"
    case $? in
    0)
    echo 0 | 2>/dev/null 1>&2 trash-restore "$RESTORE"
    ;;
    esac
fi
