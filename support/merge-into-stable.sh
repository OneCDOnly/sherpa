#!/usr/bin/env bash

if [[ ! -e vars.source ]]; then
	echo "'vars.source' not found"
	exit 1
fi

. ./vars.source

echo -en "ready to merge '$unstable_branch_msg' branch into '$stable_branch_msg' branch: proceed? "
read -rn1 response
echo

case ${response:0:1} in
	y|Y)
		: # OK to continue
		;;
	*)
		exit 0
esac

./make.sh "$stable_branch" || exit

cd $HOME/scripts/nas/sherpa || exit
git add . && git commit -m '[pre-merge] update archives' && git push
git checkout "$stable_branch"
git merge --no-ff -m "[merge] from \`$unstable_branch\` into \`$stable_branch\`" "$unstable_branch" && git push
git checkout "$unstable_branch"
git merge "$stable_branch" --strategy=ours && git push		# ensure remote 'unstable' is up-to-date with 'stable'
cd $HOME/scripts/nas/sherpa/support || exit

exit 0
