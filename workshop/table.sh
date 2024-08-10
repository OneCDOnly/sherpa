#!/usr/bin/env bash

readonly REPORT_OUTPUT_PATHFILE=report.ansi

Tabilise()
	{

	# Generate an ANSI-aware table with auto-width columns.

	# With many thanks to Stephane Chazelas for writing this:
	#  	  https://unix.stackexchange.com/a/121139/259233

	awk '{
		nf[NR]=NF
		for (i = 1; i <= NF; i++) {
			cell[NR,i] = $i
			gsub(/\033\[[0-9;]*[mK]/, "", $i)
			len[NR,i] = l = length($i)
			if (l > max[i]) max[i] = l
		}
	}
	END {
		for (row = 1; row <= NR; row++) {
			for (col = 1; col < nf[row]; col++)
				printf "%s%*s%s", cell[row,col], max[col]-len[row,col], "", OFS
			print cell[row,nf[row]]
		}

	}' FS='|' OFS='  '

	}

Tabilise < "$REPORT_OUTPUT_PATHFILE"
