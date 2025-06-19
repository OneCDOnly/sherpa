#!/usr/bin/env bash

certificate_db_pathfile=/etc/config/nas_sign_qpkg.db
# qpkg_name=RusnLast
qpkg_name=helpdesk

a="SELECT 1 from Certificate WHERE QpkgName = '$qpkg_name'"
b=''

read -r -d '' b <<EOB
import sqlite3, sys

try:
    sqliteConnection = sqlite3.connect('$certificate_db_pathfile')

    cursor = sqliteConnection.cursor()
    sqlite_select_query = """$a"""
    cursor.execute(sqlite_select_query)
    records = cursor.fetchall()
    sys.exit(len(records) == 0)
    cursor.close()

finally:
    if sqliteConnection:
        sqliteConnection.close()
EOB

/usr/local/bin/python2 -c "$b"
