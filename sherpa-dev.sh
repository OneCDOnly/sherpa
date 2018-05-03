#!/usr/bin/env bash
###############################################################################
# sherpa.sh
#
# (C)opyright 2017-2018 OneCD - one.cd.only@gmail.com
#
# So, blame OneCD if it all goes horribly wrong. ;)
#
# For more info [https://forum.qnap.com/viewtopic.php?f=320&t=132373]
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see http://www.gnu.org/licenses/.
###############################################################################
# * Style Guide *
# function names: CamelCase
# variable names: lowercase_with_underscores (except for 'returncode' & 'errorcode')
# constants: UPPERCASE_WITH_UNDERSCORES
# indents: tab (4 spaces)
###############################################################################

USER_ARGS_RAW="$@"

Init()
	{

	GETCFG_CMD=/sbin/getcfg
	UNAME_CMD=/bin/uname
	TR_CMD=/bin/tr
	GREP_CMD=/bin/grep

	debug=true

	local ULINUX_PATHFILE=/etc/config/uLinux.conf
	PACKAGES_PATHFILE=packages.conf

	FIRMWARE_VERSION="$($GETCFG_CMD System Version -f "$ULINUX_PATHFILE")"
	NAS_ARCH="$($UNAME_CMD -m)"
	CalcQPKGArch

	}

CalcQPKGArch()
	{

	# adapt package arch depending on NAS arch

	case $NAS_ARCH in
		x86_64)
			[[ ${FIRMWARE_VERSION//.} -ge 430 ]] && QPKG_ARCH=x64 || QPKG_ARCH=x86
			;;
		i686)
			QPKG_ARCH=x86
			;;
		*)
			QPKG_ARCH=$NAS_ARCH
			;;
	esac

	DebugVar QPKG_ARCH
	return 0

	}

DebugInfoThickSeparator()
	{

	DebugInfo "$(printf '%0.s=' {1..69})"

	}

DebugInfoThinSeparator()
	{

	DebugInfo "$(printf '%0.s-' {1..69})"

	}

DebugErrorThinSeparator()
	{

	DebugError "$(printf '%0.s-' {1..69})"

	}

DebugScript()
	{

	DebugDetected 'SCRIPT' "$1" "$2"

	}

DebugStage()
	{

	DebugDetected 'STAGE' "$1" "$2"

	}

DebugNAS()
	{

	DebugDetected 'NAS' "$1" "$2"

	}

DebugQPKG()
	{

	DebugDetected 'QPKG' "$1" "$2"

	}

DebugIPKG()
	{

	DebugDetected 'IPKG' "$1" "$2"

	}

DebugFuncEntry()
	{

	DebugThis "(>>) <${FUNCNAME[1]}>"

	}

DebugFuncExit()
	{

	DebugThis "(<<) <${FUNCNAME[1]}> [$errorcode]"

	}

DebugProc()
	{

	DebugThis "(==) $1 ..."

	}

DebugDone()
	{

	DebugThis "(--) $1"

	}

DebugDetected()
	{

	DebugThis "(**) $(printf "%-7s %17s %-s\n" "$1:" "$2:" "$3")"

	}

DebugInfo()
	{

	DebugThis "(II) $1"

	}

DebugWarning()
	{

	DebugThis "(WW) $1"

	}

DebugError()
	{

	DebugThis "(EE) $1"

	}

DebugVar()
	{

	DebugThis "(vv) $1 [${!1}]"

	}

DebugThis()
	{

	[[ $debug = true ]] && ShowDebug "$1"
	SaveDebug "$1"

	}

DebugErrorFile()
	{

	# add the contents of specified pathfile $1 to the main runtime log

	[[ -z $1 || ! -e $1 ]] && return 1
	local linebuff=''

	DebugErrorThinSeparator
	DebugError "[$1]"
	DebugErrorThinSeparator

	while read linebuff; do
		DebugError "$linebuff"
	done < "$1"

	DebugErrorThinSeparator

	}

ShowInfo()
	{

	ShowLogLine_write "$(ColourTextBrightWhite info)" "$1"
	SaveLogLine info "$1"

	}

ShowProc()
	{

	ShowLogLine_write "$(ColourTextBrightOrange proc)" "$1 ..."
	SaveLogLine proc "$1 ..."

	}

ShowDebug()
	{

	ShowLogLine_write "$(ColourTextBlackOnCyan dbug)" "$1"

	}

ShowDone()
	{

	ShowLogLine_update "$(ColourTextBrightGreen done)" "$1"
	SaveLogLine done "$1"

	}

ShowWarning()
	{

	ShowLogLine_update "$(ColourTextBrightOrange warn)" "$1"
	SaveLogLine warn "$1"

	}

ShowError()
	{

	ShowLogLine_update "$(ColourTextBrightRed fail)" "$1"
	SaveLogLine fail "$1"

	}

SaveDebug()
	{

	SaveLogLine dbug "$1"

	}

ShowLogLine_write()
	{

	# writes a new message without newline (unless in debug mode)

	# $1 = pass/fail
	# $2 = message

	previous_msg=$(printf "[ %-10s ] %s" "$1" "$2")

	echo -n "$previous_msg"; [[ $debug = true ]] && echo

	return 0

	}

ShowLogLine_update()
	{

	# updates the previous message

	# $1 = pass/fail
	# $2 = message

	new_message=$(printf "[ %-10s ] %s" "$1" "$2")

	if [[ $new_message != $previous_msg ]]; then
		previous_length=$((${#previous_msg}+1))
		new_length=$((${#new_message}+1))

		# jump to start of line, print new msg
		strbuffer=$(echo -en "\r$new_message ")

		# if new msg is shorter then add spaces to end to cover previous msg
		[[ $new_length -lt $previous_length ]] && { appended_length=$(($new_length-$previous_length)); strbuffer+=$(printf "%${appended_length}s") ;}

		echo "$strbuffer"
	fi

	return 0

	}

SaveLogLine()
	{

	# $1 = pass/fail
	# $2 = message

	[[ -n $DEBUG_LOG_PATHFILE ]] && $TOUCH_CMD "$DEBUG_LOG_PATHFILE" && printf "[ %-4s ] %s\n" "$1" "$2" >> "$DEBUG_LOG_PATHFILE"

	}

ColourTextBrightGreen()
	{

	echo -en '\E[1;32m'"$(PrintResetColours "$1")"

	}

ColourTextBrightOrange()
	{

	echo -en '\E[1;38;5;214m'"$(PrintResetColours "$1")"

	}

ColourTextBrightRed()
	{

	echo -en '\E[1;31m'"$(PrintResetColours "$1")"

	}

ColourTextUnderlinedBlue()
	{

	echo -en '\E[4;94m'"$(PrintResetColours "$1")"

	}

ColourTextBlackOnCyan()
	{

	echo -en '\E[30;46m'"$(PrintResetColours "$1")"

	}

ColourTextBrightWhite()
	{

	echo -en '\E[1;97m'"$(PrintResetColours "$1")"

	}

PrintResetColours()
	{

	echo -en "$1"'\E[0m'

	}

LoadUserInstallablePackageNames()
	{

	# read all available package names from downloaded package list

	[[ -n $user_installable_packages ]] && return

	local label=''
	local name=''
	local arch=''
	local acc=0
	local plural=''
	user_installable_packages=()

	echo "- loading sherpa installable packages ..."
	for label in $(grep '^\[' $PACKAGES_PATHFILE); do
        name_arch=${label//[\[\]]}; name=${name_arch%@*}; arch=${name_arch#$name@}
        if [[ $arch = $NAS_ARCH || $arch = all ]]; then
			if ($GETCFG_CMD $name_arch aliases -f $PACKAGES_PATHFILE > /dev/null 2>&1); then
				user_installable_packages+=($name)
				((acc++))
				[[ $arch = all ]] && plural=s || plural=''
				#echo "$name for $arch architecture${plural}"
			fi
		fi
    done

    #echo "* $acc packages are available for installation"
    #echo
    #echo ${user_installable_packages[*]}

	}

ShowPackagesAliases()
	{

	local label=''
	local name_arch=''
	local name=''
	local arch=''
	local acc=0

	printf '%0.s-' {1..80}; echo
	printf " %-20s: %s\n" "package name" "acceptable aliases"
	printf '%0.s-' {1..80}; echo
	for label in $($GREP_CMD '^\[' $PACKAGES_PATHFILE); do
        name_arch=${label//[\[\]]}; name=${name_arch%@*}; arch=${name_arch#$name@}
        if [[ $arch = $NAS_ARCH || $arch = all ]]; then
			if ($GETCFG_CMD $name_arch aliases -f $PACKAGES_PATHFILE > /dev/null 2>&1); then
				printf " %-20s: %s\n" "$name" "$($GETCFG_CMD $name_arch aliases -f $PACKAGES_PATHFILE)"
				((acc++))
			fi
		fi
    done
	printf '%0.s-' {1..80}; echo
    echo " = $acc packages are available for installation"
	printf '%0.s-' {1..80}; echo

	}

MatchAliasToPackage()
	{

	local label=''
	local name=''
	local arch=''
	qpkg_url=''
	qpkg_md5=''

	request=$(echo "$USER_ARGS_RAW" | $TR_CMD '[A-Z]' '[a-z]')

	for label in $($GREP_CMD '^\[' $PACKAGES_PATHFILE); do
        name_arch=${label//[\[\]]}; name=${name_arch%@*}; arch=${name_arch#$name@}
        if [[ $arch = $NAS_ARCH || $arch = all ]]; then
			if ($GETCFG_CMD $name_arch aliases -f $PACKAGES_PATHFILE > /dev/null 2>&1); then
				aliases=( $($GETCFG_CMD $name_arch aliases -f $PACKAGES_PATHFILE | $TR_CMD ',' ' ') )
				for alias in "${aliases[@]}"; do
					if [[ $alias = $request ]]; then
						echo "package match found: $name"
						TARGET_APP=$name
						qpkg_url=$($GETCFG_CMD "$name_arch" url -f $PACKAGES_PATHFILE)
						qpkg_md5=$($GETCFG_CMD "$name_arch" md5 -f $PACKAGES_PATHFILE)
						break 2
					fi
				done
			fi
		fi
    done

	}

LoadQPKGFileDetails_beta()
	{

	# $1 = QPKG name

	qpkg_url=''
	qpkg_md5=''
	qpkg_file=''
	qpkg_pathfile=''

	if [[ -z $1 ]]; then
		DebugError 'QPKG name unspecified'
		errorcode=31
		returncode=1
	else

		for i in "${user_installable_packages[@]}"; do
			aliases=( $($GETCFG_CMD $name_arch aliases -f $PACKAGES_PATHFILE | tr ',' '') )

			#for alias in "${aliases[@]}"
			#for alias in $($GETCFG_CMD $name_arch aliases -f $PACKAGES_PATHFILE | tr "," "\n")
				#if [[ $alias = $1 ]]; then

					#name_arch="${1}@$NAS_ARCH"

				qpkg_name=$alias
					qpkg_url=$($GETCFG_CMD "$name_arch" url -f $PACKAGES_PATHFILE)
					qpkg_md5=$($GETCFG_CMD "$name_arch" md5 -f $PACKAGES_PATHFILE)

			#		break 2
			#done
		done


		if [[ -z $qpkg_url || -z $qpkg_md5 ]]; then
			DebugError 'QPKG details not found'
			errorcode=33
			returncode=1
		else
			[[ -z $qpkg_file ]] && qpkg_file=$($BASENAME_CMD "$qpkg_url")
			qpkg_pathfile="${QPKG_DL_PATH}/${qpkg_file}"
		fi
	fi

	return $returncode

	}

LoadQPKGFileDetails()
	{

	# $1 = QPKG name

	qpkg_url=''
	qpkg_md5=''
	qpkg_file=''
	qpkg_pathfile=''
	local returncode=0
	local target_file=''
	local OneCD_url_prefix='https://raw.githubusercontent.com/onecdonly/sherpa/master/QPKGs'
	local Stephane_url_prefix='http://www.qoolbox.fr'

	if [[ -z $1 ]]; then
		DebugError 'QPKG name unspecified'
		errorcode=31
		returncode=1
	else
		qpkg_name=$1
		local base_url=''

		case $1 in
			Entware)
				qpkg_url='http://bin.entware.net/other/Entware_1.00std.qpkg'
				qpkg_md5='0c99cf2cf8ef61c7a18b42651a37da74'
				;;
			Entware-3x)
				qpkg_url='http://entware-3x.zyxmon.org/binaries/other/Entware-3x_1.00std.qpkg'
				qpkg_md5='fa5719ab2138c96530287da8e6812746'
				;;
			Entware-ng)
				qpkg_url='http://entware.zyxmon.org/binaries/other/Entware-ng_0.97.qpkg'
				qpkg_md5='6c81cc37cbadd85adfb2751dc06a238f'
				;;
			SABnzbdplus)
				qpkg_url="${OneCD_url_prefix}/SABnzbdplus/build/SABnzbdplus_180427.qpkg"
				qpkg_md5='fe25532df893ef2227f5efa28c3f38af'
				;;
			SickRage)
				qpkg_url="${OneCD_url_prefix}/SickRage/build/SickRage_180427.qpkg"
				qpkg_md5='0fd4ffc7d00ad0f9a1e475e7a784d6df'
				;;
			CouchPotato2)
				qpkg_url="${OneCD_url_prefix}/CouchPotato2/build/CouchPotato2_180427.qpkg"
				qpkg_md5='395ffdb9c25d0bc07eb24987cc722cdb'
				;;
			LazyLibrarian)
				qpkg_url="${OneCD_url_prefix}/LazyLibrarian/build/LazyLibrarian_180427.qpkg"
				qpkg_md5='fdb4595f2970a498b9ef73a8b5f3a4b4'
				;;
			OMedusa)
				qpkg_url="${OneCD_url_prefix}/OMedusa/build/OMedusa_180427.qpkg"
				qpkg_md5='ec3b193c7931a100067cfaa334caf883'
				;;
			Headphones)
				qpkg_url="${OneCD_url_prefix}/Headphones/build/Headphones_180429.qpkg"
				qpkg_md5='c1b5ba10f5636b4e951eb57fb2bb1ed5'
				;;
			Par2cmdline-MT)
				case $STEPHANE_QPKG_ARCH in
					x86)
						qpkg_url="${Stephane_url_prefix}/Par2cmdline-MT_0.6.14-MT_x86.qpkg.zip"
						qpkg_md5='531832a39576e399f646890cc18969bb'
						;;
					x64)
						qpkg_url="${Stephane_url_prefix}/Par2cmdline-MT_0.6.14-MT_x86_64.qpkg.zip"
						qpkg_md5='f3b3dd496289510ec0383cf083a50f8e'
						;;
					x41)
						qpkg_url="${Stephane_url_prefix}/Par2cmdline-MT_0.6.14-MT_arm-x41.qpkg.zip"
						qpkg_md5='1701b188115758c151f19956388b90cb'
						;;
				esac
				;;
			Par2)
				case $STEPHANE_QPKG_ARCH in
					x64)
						qpkg_url="${Stephane_url_prefix}/Par2_0.7.4.0_x86_64.qpkg.zip"
						qpkg_md5='660882474ab00d4793a674d4b48f89be'
						;;
					x41)
						qpkg_url="${Stephane_url_prefix}/Par2_0.7.4.0_arm-x41.qpkg.zip"
						qpkg_md5='9c0c9d3e8512f403f183856fb80091a4'
						;;
				esac
				;;
			*)
				DebugError 'QPKG name not found'
				errorcode=32
				returncode=1
				;;
		esac

		if [[ -z $qpkg_url || -z $qpkg_md5 ]]; then
			DebugError 'QPKG details not found'
			errorcode=33
			returncode=1
		else
			[[ -z $qpkg_file ]] && qpkg_file=$($BASENAME_CMD "$qpkg_url")
			qpkg_pathfile="${QPKG_DL_PATH}/${qpkg_file}"
		fi
	fi

	return $returncode

	}

Init
#ShowPackagesAliases
MatchAliasToPackage "$USER_ARGS_RAW"

echo "target app: $TARGET_APP"
echo "url: $qpkg_url"
echo "md5: $qpkg_md5"

exit
LoadUserInstallablePackageNames
LoadQPKGFileDetails_beta "$USER_ARGS_RAW"
