#!/usr/bin/env bash

rm *.ipk

source_url=$(grep -o 'http://.*' /opt/etc/opkg.conf)
pkg_base=python3
pkg_names=(asyncio base cgi cgitb codecs ctypes dbm decimal dev distutils email gdbm lib2to3 light logging lzma multiprocessing ncurses openssl pydoc sqlite3 unittest urllib xml)
pkg_version=3.7.4-2
pkg_arch=$(basename $source_url | sed 's|\-k|\-|;s|sf\-|\-|')
pkg_name=''
ipkg_urls=()

for pkg_name in ${pkg_names[@]}; do
    ipkg_urls+=(-O "${source_url}/archive/${pkg_base}-${pkg_name}_${pkg_version}_${pkg_arch}.ipk")
done

# and this package too
ipkg_urls+=(-O "${source_url}/archive/${pkg_base}_${pkg_version}_${pkg_arch}.ipk")

curl ${ipkg_urls[@]}

opkg install --force-downgrade *.ipk

rm *.ipk
