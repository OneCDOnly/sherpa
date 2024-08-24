#!/usr/bin/env bash

for a in $(grep '^\[.*\]$' qpkg.conf | sed 's|\[||;s|\]||;/RunLast/d'); do
	[[ -n $b ]] && b+=":$a" || b=$a
done

echo "$b"
