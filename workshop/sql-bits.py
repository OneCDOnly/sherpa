#!/usr/bin/env python2

# https://pynative.com/python-sqlite-select-from-table/
# https://pynative.com/python-sqlite-insert-into-table/

import sqlite3

try:
    sqliteConnection = sqlite3.connect('nas_sign_qpkg.db')
    cursor = sqliteConnection.cursor()

    sqlite_select_query = """SELECT 1 from Certificate WHERE QpkgName = 'RunLast'"""
    cursor.execute(sqlite_select_query)
    records = cursor.fetchall()

    if len(records) == 1:
        print('true')
    else:
        print('false')

    cursor.close()

finally:
    if sqliteConnection:
        sqliteConnection.close()
