#!/usr/bin/env bash

stable_branch=main
unstable_branch=unstable

echo -n "ready to merge '$unstable_branch' branch into '$stable_branch' branch: proceed? "
read -rn1 response
echo

case ${response:0:1} in
    y|Y)
        : # OK to continue
        ;;
    *)
        exit 0
esac

echo "$stable_branch" > "$HOME"/scripts/nas/sherpa/support/branch.txt

./make.sh || exit

cd "$HOME"/scripts/nas/sherpa || exit
git add . && git commit -m "scripted merge from \`$unstable_branch\`" && git push
git checkout "$stable_branch"
git merge "$unstable_branch" && git push
git checkout "$unstable_branch"
cd "$HOME"/scripts/nas/sherpa/support || exit

echo "$unstable_branch" > "$HOME"/scripts/nas/sherpa/support/branch.txt

exit 0
