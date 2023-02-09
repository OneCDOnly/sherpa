#!/usr/bin/env bash

echo 'unstable' > "$HOME"/scripts/nas/sherpa/support/branch.txt

cd "$HOME"/scripts/nas/sherpa || exit
git add . && git commit && git push
cd "$HOME"/scripts/nas/sherpa/support || exit

exit 0
