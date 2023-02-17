#!/usr/bin/env bash

if [[ -e vars.source ]]; then
	. ./vars.source
else
	ColourTextBrightRed "'vars.source' not found\n"
	exit 1
fi

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

echo "$stable_branch" > "$branch_pathfile"

./make.sh || exit

cd "$HOME"/scripts/nas/sherpa || exit
git add . && git commit -m 'update archives' && git push
git checkout "$stable_branch"
git merge --no-ff -m "merge from \`$unstable_branch\` into \`$stable_branch\`" "$unstable_branch" && git push
git checkout "$unstable_branch"
cd "$HOME"/scripts/nas/sherpa/support || exit

echo "$unstable_branch" > "$branch_pathfile"

exit 0
