#!/usr/bin/env bash

. vars.source || exit

release_tag=v${build_date}

echo -en "ready to merge '$(ColourTextBrightRed "$unstable_branch")' branch into '$(ColourTextBrightGreen "$stable_branch")' branch as '$(ColourTextBrightWhite "$release_tag")': proceed? "
read -rn1 response
echo

case ${response:0:1} in
	y|Y)
		: # OK to continue
		;;
	*)
		exit 0
esac

cd "$support_path" || exit

./build-all.sh || exit

$support_path/commit.sh '[update] archives [pre-merge]' || exit

cd "$root_path" || exit

git checkout "$stable_branch" || exit
git merge --no-ff -m "[merge] from \`$unstable_branch\` into \`$stable_branch\`" "$unstable_branch" && git push || exit
git tag "$release_tag"
git push --tags
git checkout "$unstable_branch" || exit

gh release create "$release_tag" --generate-notes "$qpkgs_path/sherpa/build/sherpa.qpkg"

cd "$support_path" || exit
