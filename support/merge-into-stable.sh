#!/usr/bin/env bash

. vars.source || exit

echo -en "ready to merge the current '$unstable_branch_msg' branch into '$stable_branch_msg' branch: proceed? "
read -rn1 response
echo

case ${response:0:1} in
	y|Y)
		: # OK to continue
		;;
	*)
		exit 0
esac

cd $HOME/scripts/nas/sherpa/support || exit

./build-all.sh || exit
./build-readme.sh || exit
./build-forum-announcement.sh || exit
./commit.sh '[update] archives [pre-merge]' || exit

cd $HOME/scripts/nas/sherpa || exit

git checkout "$stable_branch" || exit
git merge --no-ff -m "[merge] from \`$unstable_branch\` into \`$stable_branch\`" "$unstable_branch" && git push || exit
git tag v${build_date}
git push --tags
git checkout "$unstable_branch" || exit

cd $HOME/scripts/nas/sherpa/support || exit

./build-all.sh || exit
./commit.sh '[update] QPKGs rebuild [post-merge]' || exit

exit 0
