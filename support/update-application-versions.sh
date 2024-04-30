#!/usr/bin/env bash

. vars.source || exit

git add "$packages_source_file" && git commit -m '[update] application version(s)' && git push
