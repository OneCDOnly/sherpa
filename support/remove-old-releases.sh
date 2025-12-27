#!/usr/bin/env bash

releases_to_keep=30

while read -r release; do
	[[ -n $release ]] || continue
   	gh release delete -y --cleanup-tag "$release"
done <<< "$(gh release list --limit 200 | awk -F '\t' '{print $3}' | grep -v testing | tail --lines +$((releases_to_keep+1)))"
