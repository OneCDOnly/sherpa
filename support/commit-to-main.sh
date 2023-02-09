#!/usr/bin/env bash

echo -n "about to commit to 'main' branch: proceed? "
read -rn1 response
echo

case ${response:0:1} in
    y|Y)
        : # OK to continue
        ;;
    *)
        exit 0
esac

echo 'main' > "$HOME"/scripts/nas/sherpa/support/branch.txt

./make.sh || exit

cd "$HOME"/scripts/nas/sherpa || exit
git add . && git commit -m '[scripted] update archives' && git push
git checkout main
git merge unstable && git push
git checkout unstable
cd "$HOME"/scripts/nas/sherpa/support || exit

echo 'unstable' > "$HOME"/scripts/nas/sherpa/support/branch.txt

exit 0
