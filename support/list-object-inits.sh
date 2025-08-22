#!/usr/bin/env bash

. $HOME/scripts/nas/sherpa/support/environment.sourced || exit

a=$support_path/$objects_file

[[ ! -e $a ]] && ./build-objects.sh

grep '.Init()' "$a" | sort
