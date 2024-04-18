#!/usr/bin/env bash

. vars.source || exit

git add "$docs_path" && git commit -m '[update] readme doc(s)' && git push

exit 0
