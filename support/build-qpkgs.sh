#!/usr/bin/env bash

for d in */; do
	(cd "$d" && qbuild)
done
