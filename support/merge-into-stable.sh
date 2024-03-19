#!/usr/bin/env bash

. vars.source || exit

release_tag=v${build_date}

echo -en "ready to merge the current '$(ColourTextBrightRed "$unstable_branch")' branch into '$(ColourTextBrightGreen "$stable_branch")' branch as '$(ColourTextBrightWhite "$release_tag")': proceed? "
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
git tag "$release_tag"
git push --tags
git checkout "$unstable_branch" || exit

cd $HOME/scripts/nas/sherpa/support || exit

# ./build-all.sh || exit
./reset-qpkg-datetimes.sh || exit
./commit.sh '[update] datetimes reset [post-merge]' || exit

exit 0
