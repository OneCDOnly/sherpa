#!/usr/bin/env bash

set -o nounset

ass()
	{

	echo 'me'

	}

echo "echoing: '${r:=$(ass)}'"

echo "follow-up: '$r'"
