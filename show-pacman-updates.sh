#!/usr/bin/env sh

fakeroot pacman -Qu --dbpath /tmp/checkup-db-i3statusrs/ | \
bemenu \
--list 40 \
--prompt " Mises à jour en attente" \
--no-exec
