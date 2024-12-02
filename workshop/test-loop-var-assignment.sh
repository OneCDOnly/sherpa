#!/usr/bin/env bash

init()
	{

active_test=false
local active_test_msg='active first'

autoupdate=false
autoupdate_msg='auto second'

backup=false
backup_msg='back third'

clean=false
clean_msg='clen fourth'

echo "before:"
echo -e "\t$active_test_msg"
echo -e "\t$autoupdate_msg"
echo -e "\t$backup_msg"
echo -e "\t$clean_msg"

a=''
b=''

for a in active_test autoupdate backup clean; do
# 	if [[ ${!a} = true ]]; then
		: # "$a"_msg=$(TextBrightGreen "${!a}_msg")
# 	else
 		b=${a}_msg
 		local ${a}_msg="${!b} addendum"
# 	fi
done

echo "after:"
echo -e "\t$active_test_msg"
echo -e "\t$autoupdate_msg"
echo -e "\t$backup_msg"
echo -e "\t$clean_msg"

 }

init
