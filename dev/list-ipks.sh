#!/usr/bin/env bash

while read -r packname sep version; do
   echo "$packname"
done <<< "$(opkg list-installed)"
