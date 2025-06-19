#!/usr/bin/env bash

certificate_db_pathfile=nas_sign_qpkg.db
qpkg_name=RunLast

read -r -d '' a <<EOB
import sqlite3, sys

try:
    sqliteConnection = sqlite3.connect('$certificate_db_pathfile')

    cursor = sqliteConnection.cursor()
    sqlite_select_query = """SELECT 1 from Certificate WHERE QpkgName = '$qpkg_name'"""
    cursor.execute(sqlite_select_query)
    records = cursor.fetchall()
    sys.exit(len(records) == 0)
    cursor.close()

finally:
    if sqliteConnection:
        sqliteConnection.close()
EOB

python2 -c "$a"
