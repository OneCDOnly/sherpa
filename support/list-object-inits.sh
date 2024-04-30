#!/usr/bin/env bash

. vars.source || exit

a=$support_path/$objects_file

[[ ! -e $a ]] && ./build-objects.sh

grep '.Init()' "$a" | sort
