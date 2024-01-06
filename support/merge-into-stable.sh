#!/usr/bin/env bash

. vars.source || exit

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

# ./make.sh || exit

cd $HOME/scripts/nas/sherpa || exit
# git add . && git commit -m '[pre-merge] update archives' && git push
git checkout "$stable_branch" || exit
git merge --no-ff -m "[merge] from \`$unstable_branch\` into \`$stable_branch\`" "$unstable_branch" && git push
git checkout "$unstable_branch" || exit
git merge "$stable_branch" --strategy=ours -m '[post-merge] writeback' && git push		# ensure remote 'unstable' is up-to-date with 'stable'
cd $HOME/scripts/nas/sherpa/support || exit

exit 0
