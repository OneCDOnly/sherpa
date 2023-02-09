#!/usr/bin/env bash

echo 'main' > "$HOME"/scripts/nas/sherpa/support/branch.txt

./make.sh || exit

cd "$HOME"/scripts/nas/sherpa || exit
git add . && git commit -m '[scripted] update archives' && git push
git checkout main
git merge unstable && git push
git checkout unstable

echo 'unstable' > "$HOME"/scripts/nas/sherpa/support/branch.txt

exit 0
