#!/usr/bin/env bash

/opt/bin/column --table --output-width=90 --separator='|' \
	--table-column name=epoch \
	--table-column name=status \
	--table-column name=name \
	--table-column name=result \
	--table-column name=duration \
	--table-column name=reason,wrap \
	--table-column name=type \
	test-table-input.txt
