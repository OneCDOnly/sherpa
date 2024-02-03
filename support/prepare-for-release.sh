#!/usr/bin/env bash

# touch a file in the main sherpa QPKG so it will be rebuilt by 'build-qpkgs.sh'

. vars.source || exit

touch "$qpkgs_path"/sherpa/qpkg.source
