#!/usr/bin/env bash

work_path="$HOME"/scripts/nas/sherpa/support
push_path="$HOME"/scripts/nas/sherpa

echo 'unstable' > "$work_path"/branch.txt

cd "$push_path" || exit
git add . && git commit && git push
cd "$work_path" || exit

exit 0
