#!/bin/sh

##############################################################
##           _           __  __              _  _           ##
##          | |         |  \/  |            | |(_)          ##
##    _ __  | |_  _ __  | \  / |  ___  _ __ | | _  _ __     ##
##   | '_ \ | __|| '_ \ | |\/| | / _ \| '__|| || || '_ \    ##
##   | | | || |_ | |_) || |  | ||  __/| |   | || || | | |   ##
##   |_| |_| \__|| .__/ |_|  |_| \___||_|   |_||_||_| |_|   ##
##               | |                                        ##
##               |_|                                        ##
##                                                          ##
##           https://github.com/AMTM-OSR/ntpMerlin          ##
##     Forked from https://github.com/jackyaz/ntpMerlin     ##
##                                                          ##
##############################################################
# Last Modified: 2026-Jun-24
#-------------------------------------------------------------

###############       Shellcheck directives      #############
# shellcheck disable=SC2009
# shellcheck disable=SC2012
# shellcheck disable=SC2016
# shellcheck disable=SC2018
# shellcheck disable=SC2019
# shellcheck disable=SC2059
# shellcheck disable=SC2086
# shellcheck disable=SC2155
# shellcheck disable=SC2174
# shellcheck disable=SC3018
# shellcheck disable=SC3037
# shellcheck disable=SC3043
# shellcheck disable=SC3045
##############################################################

### Start of script variables ###
readonly SCRIPT_NAME="ntpMerlin"
readonly SCRIPT_NAME_LOWER="$(echo "$SCRIPT_NAME" | tr 'A-Z' 'a-z' | sed 's/d//')"
readonly SCRIPT_VERSION="v3.4.16"
readonly SCRIPT_VERSTAG="26062400"
SCRIPT_BRANCH="develop"
SCRIPT_REPO="https://raw.githubusercontent.com/AMTM-OSR/$SCRIPT_NAME/$SCRIPT_BRANCH"
readonly SCRIPT_DIR="/jffs/addons/$SCRIPT_NAME_LOWER.d"
readonly SCRIPT_WEBPAGE_DIR="$(readlink -f /www/user)"
readonly SCRIPT_WEB_DIR="$SCRIPT_WEBPAGE_DIR/$SCRIPT_NAME_LOWER"
readonly SHARED_DIR="/jffs/addons/shared-jy"
readonly SHARED_REPO="https://raw.githubusercontent.com/AMTM-OSR/shared-jy/master"
readonly SHARED_WEB_DIR="$SCRIPT_WEBPAGE_DIR/shared-jy"
readonly TEMP_MENU_TREE="/tmp/menuTree.js"

[ -z "$(nvram get odmpid)" ] && ROUTER_MODEL="$(nvram get productid)" || ROUTER_MODEL="$(nvram get odmpid)"
[ -f /opt/bin/sqlite3 ] && SQLITE3_PATH=/opt/bin/sqlite3 || SQLITE3_PATH=/usr/sbin/sqlite3

##-------------------------------------##
## Added by Martinski W. [2025-Feb-15] ##
##-------------------------------------##
readonly scriptVersRegExp="v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})"
readonly webPageMenuAddons="menuName: \"Addons\","
readonly webPageHelpSupprt="tabName: \"Help & Support\"},"
readonly webPageFileRegExp="user([1-9]|[1-2][0-9])[.]asp"
readonly webPageLineTabExp="\{url: \"$webPageFileRegExp\", tabName: "
readonly webPageLineRegExp="${webPageLineTabExp}\"$SCRIPT_NAME\"\},"
readonly BEGIN_MenuAddOnsTag="/\*\*BEGIN:_AddOns_\*\*/"
readonly ENDIN_MenuAddOnsTag="/\*\*ENDIN:_AddOns_\*\*/"
readonly branchxStr_TAG="[Branch: $SCRIPT_BRANCH]"
readonly versionDev_TAG="${SCRIPT_VERSION}_${SCRIPT_VERSTAG}"
readonly versionMod_TAG="$SCRIPT_VERSION on $ROUTER_MODEL"

# To support automatic script updates from AMTM #
doScriptUpdateFromAMTM=true

# For daily CRON job to trim database #
readonly defTrimDB_Hour=3
readonly defTrimDB_Mins=7

readonly _12Hours=43200
readonly _24Hours=86400
readonly _36Hours=129600
readonly oneKByte=1024
readonly oneMByte=1048576
readonly ei8MByte=8388608
readonly ni9MByte=9437184
readonly tenMByte=10485760
readonly oneGByte=1073741824
readonly SHARE_TEMP_DIR="/opt/share/tmp"

##-------------------------------------##
## Added by Martinski W. [2025-Jun-04] ##
##-------------------------------------##
readonly sqlDBLogFileSize=102400
readonly sqlDBLogDateTime="%Y-%m-%d %H:%M:%S"
readonly sqlDBLogFileName="${SCRIPT_NAME}_DBSQL_DEBUG.LOG"

### End of script variables ###

### Start of output format variables ###
readonly CRIT="\\e[41m"
readonly ERR="\\e[31m"
readonly WARN="\\e[33m"
readonly PASS="\\e[32m"
readonly BOLD="\\e[1m"
readonly SETTING="${BOLD}\\e[36m"
readonly CLEARFORMAT="\\e[0m"

##-------------------------------------##
## Added by Martinski W. [2025-Feb-15] ##
##-------------------------------------##
readonly CLRct="\e[0m"
readonly REDct="\e[1;31m"
readonly GRNct="\e[1;32m"
readonly MGNTct="\e[1;35m"
readonly CritIREDct="\e[41m"
readonly CritBREDct="\e[30;101m"
readonly PassBGRNct="\e[30;102m"
readonly WarnBYLWct="\e[30;103m"
readonly WarnIMGNct="\e[45m"
readonly WarnBMGNct="\e[30;105m"
readonly BOLDUNDERLN="\e[1;4m"
readonly menuSepStr="${BOLD}##############################################################${CLRct}"

### End of output format variables ###

# Workaround for Entware ELF binaries compiled with RUNPATH #
unset LD_LIBRARY_PATH

# Give priority to built-in binaries #
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:$PATH"

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-04] ##
##----------------------------------------##
# $1 = print to syslog, $2 = message to print, $3 = log level
Print_Output()
{
	local prioStr  prioNum
	if [ $# -gt 2 ] && [ -n "$3" ]
	then prioStr="$3"
	else prioStr="NOTICE"
	fi
	if [ "$1" = "true" ]
	then
		case "$prioStr" in
		    "$CRIT") prioNum=2 ;;
		     "$ERR") prioNum=3 ;;
		    "$WARN") prioNum=4 ;;
		    "$PASS") prioNum=6 ;; #INFO#
		          *) prioNum=5 ;; #NOTICE#
		esac
		logger -t "${SCRIPT_NAME}_[$$]" -p $prioNum "$2"
	fi
	printf "${BOLD}${3}%s${CLEARFORMAT}\n\n" "$2"
}

Firmware_Version_Check()
{
	if nvram get rc_support | grep -qF "am_addons"; then
		return 0
	else
		return 1
	fi
}

### Code for these functions inspired by https://github.com/Adamm00 - credit to @Adamm ###
Check_Lock()
{
	if [ -f "/tmp/$SCRIPT_NAME.lock" ]
	then
		ageoflock=$(($(date +%s) - $(date +%s -r /tmp/$SCRIPT_NAME.lock)))
		if [ "$ageoflock" -gt 600 ]  #10 minutes#
		then
			Print_Output true "Stale lock file found (>600 seconds old) - purging lock" "$ERR"
			kill "$(sed -n '1p' /tmp/$SCRIPT_NAME.lock)" >/dev/null 2>&1
			Clear_Lock
			echo "$$" > "/tmp/$SCRIPT_NAME.lock"
			return 0
		else
			Print_Output true "Lock file found (age: $ageoflock seconds) - stopping to prevent duplicate runs" "$ERR"
			if [ $# -eq 0 ] || [ -z "$1" ]
			then
				exit 1
			else
				if [ "$1" = "webui" ]; then
					echo 'var ntpstatus = "LOCKED";' > /tmp/detect_ntpmerlin.js
					exit 1
				fi
				return 1
			fi
		fi
	else
		echo "$$" > "/tmp/$SCRIPT_NAME.lock"
		return 0
	fi
}

Clear_Lock()
{
	rm -f "/tmp/$SCRIPT_NAME.lock" 2>/dev/null
	return 0
}

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-02] ##
##----------------------------------------##
Set_Version_Custom_Settings()
{
	SETTINGSFILE="/jffs/addons/custom_settings.txt"
	case "$1" in
		local)
			if [ -f "$SETTINGSFILE" ]
			then
				if [ "$(grep -c "^ntpmerlin_version_local" "$SETTINGSFILE")" -gt 0 ]
				then
					if [ "$2" != "$(grep "^ntpmerlin_version_local" "$SETTINGSFILE" | cut -f2 -d' ')" ]
					then
						sed -i "s/^ntpmerlin_version_local.*/ntpmerlin_version_local $2/" "$SETTINGSFILE"
					fi
				else
					echo "ntpmerlin_version_local $2" >> "$SETTINGSFILE"
				fi
			else
				echo "ntpmerlin_version_local $2" >> "$SETTINGSFILE"
			fi
		;;
		server)
			if [ -f "$SETTINGSFILE" ]
			then
				if [ "$(grep -c "^ntpmerlin_version_server" "$SETTINGSFILE")" -gt 0 ]
				then
					if [ "$2" != "$(grep "^ntpmerlin_version_server" "$SETTINGSFILE" | cut -f2 -d' ')" ]
					then
						sed -i "s/^ntpmerlin_version_server.*/ntpmerlin_version_server $2/" "$SETTINGSFILE"
					fi
				else
					echo "ntpmerlin_version_server $2" >> "$SETTINGSFILE"
				fi
			else
				echo "ntpmerlin_version_server $2" >> "$SETTINGSFILE"
			fi
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-04] ##
##----------------------------------------##
Update_Check()
{
	echo 'var updatestatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_update.js"
	doupdate="false"
	localver="$(grep "SCRIPT_VERSION=" "/jffs/scripts/$SCRIPT_NAME_LOWER" | grep -m1 -oE "$scriptVersRegExp")"
	[ -n "$localver" ] && Set_Version_Custom_Settings local "$localver"
	curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/$SCRIPT_NAME_LOWER.sh" | grep -qF "jackyaz" || \
	{ Print_Output true "404 error detected - stopping update" "$ERR"; return 1; }
	serverver="$(curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/$SCRIPT_NAME_LOWER.sh" | grep "SCRIPT_VERSION=" | grep -m1 -oE "$scriptVersRegExp")"
	if [ "$localver" != "$serverver" ]
	then
		doupdate="version"
		Set_Version_Custom_Settings server "$serverver"
		echo 'var updatestatus = "'"$serverver"'";'  > "$SCRIPT_WEB_DIR/detect_update.js"
	else
		localmd5="$(md5sum "/jffs/scripts/$SCRIPT_NAME_LOWER" | awk '{print $1}')"
		remotemd5="$(curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/$SCRIPT_NAME_LOWER.sh" | md5sum | awk '{print $1}')"
		if [ "$localmd5" != "$remotemd5" ]
		then
			doupdate="md5"
			Set_Version_Custom_Settings server "$serverver-hotfix"
			echo 'var updatestatus = "'"$serverver-hotfix"'";'  > "$SCRIPT_WEB_DIR/detect_update.js"
		fi
	fi
	if [ "$doupdate" = "false" ]; then
		echo 'var updatestatus = "None";'  > "$SCRIPT_WEB_DIR/detect_update.js"
	fi
	echo "$doupdate,$localver,$serverver"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-04] ##
##----------------------------------------##
Update_Version()
{
	if [ $# -eq 0 ] || [ -z "$1" ]
	then
		updatecheckresult="$(Update_Check)"
		isupdate="$(echo "$updatecheckresult" | cut -f1 -d',')"
		localver="$(echo "$updatecheckresult" | cut -f2 -d',')"
		serverver="$(echo "$updatecheckresult" | cut -f3 -d',')"

		if [ "$isupdate" = "version" ]
		then
			Print_Output true "New version of $SCRIPT_NAME available - $serverver" "$PASS"
		elif [ "$isupdate" = "md5" ]
		then
			Print_Output true "MD5 hash of $SCRIPT_NAME does not match - hotfix available - $serverver" "$PASS"
		fi

		if [ "$isupdate" != "false" ]
		then
			printf "\n${BOLD}Do you want to continue with the update? (y/n)${CLEARFORMAT}  "
			read -r confirm
			case "$confirm" in
				y|Y)
					printf "\n"
					Update_File shared-jy.tar.gz
					Update_File timeserverd
					TIMESERVER_NAME="$(TimeServer check)"
					if [ "$TIMESERVER_NAME" = "ntpd" ]
					then
						Update_File ntp.conf
						Update_File S77ntpd
					elif [ "$TIMESERVER_NAME" = "chronyd" ]
					then
						Update_File chrony.conf
						Update_File S77chronyd
					fi

					Update_File ntpdstats_www.asp
					Download_File "$SCRIPT_REPO/$SCRIPT_NAME_LOWER.sh" "/jffs/scripts/$SCRIPT_NAME_LOWER" && \
					Print_Output true "$SCRIPT_NAME successfully updated" "$PASS"
					chmod 0755 "/jffs/scripts/$SCRIPT_NAME_LOWER"
					Set_Version_Custom_Settings local "$serverver"
					Set_Version_Custom_Settings server "$serverver"
					Clear_Lock
					PressEnter
					exec "$0"
					exit 0
				;;
				*)
					printf "\n"
					Clear_Lock
					return 1
				;;
			esac
		else
			Print_Output true "No updates available - latest is $localver" "$WARN"
			Clear_Lock
		fi
	fi

	if [ "$1" = "force" ]
	then
		serverver="$(curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/$SCRIPT_NAME_LOWER.sh" | grep "SCRIPT_VERSION=" | grep -m1 -oE "$scriptVersRegExp")"
		Print_Output true "Downloading latest version ($serverver) of $SCRIPT_NAME" "$PASS"
		Update_File shared-jy.tar.gz
		Update_File timeserverd
		TIMESERVER_NAME="$(TimeServer check)"
		if [ "$TIMESERVER_NAME" = "ntpd" ]
		then
			Update_File ntp.conf
			Update_File S77ntpd
		elif [ "$TIMESERVER_NAME" = "chronyd" ]
		then
			Update_File chrony.conf
			Update_File S77chronyd
		fi
		Update_File ntpdstats_www.asp
		Download_File "$SCRIPT_REPO/$SCRIPT_NAME_LOWER.sh" "/jffs/scripts/$SCRIPT_NAME_LOWER" && \
		Print_Output true "$SCRIPT_NAME successfully updated" "$PASS"
		chmod 0755 "/jffs/scripts/$SCRIPT_NAME_LOWER"
		Set_Version_Custom_Settings local "$serverver"
		Set_Version_Custom_Settings server "$serverver"
		Clear_Lock
		if [ $# -lt 2 ] || [ -z "$2" ]
		then
			PressEnter
			exec "$0"
		elif [ "$2" = "unattended" ]
		then
			exec "$0" postupdate
		fi
		exit 0
	fi
}

##-------------------------------------##
## Added by Martinski W. [2026-Feb-18] ##
##-------------------------------------##
ScriptUpdateFromAMTM()
{
    if ! "$doScriptUpdateFromAMTM"
    then
        printf "Automatic script updates via AMTM are currently disabled.\n\n"
        return 1
    fi
    if [ $# -gt 0 ] && [ "$1" = "check" ]
    then return 0
    fi
    Update_Version force unattended
    return "$?"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jul-30] ##
##----------------------------------------##
Update_File()
{
	if [ "$1" = "S77ntpd" ] || [ "$1" = "S77chronyd" ]
	then
		rm -f "$SCRIPT_DIR"/S77*d
		srvceFile="$SCRIPT_DIR/$1"
		Download_File "$SCRIPT_REPO/$1" "$srvceFile"
		if ! diff -q "$srvceFile" "/opt/etc/init.d/$1" >/dev/null 2>&1
		then
			Print_Output true "New version of $1 downloaded" "$PASS"
			TimeServer_Customise
		else
			TimeServer_ServiceCheck false
		fi
	elif [ "$1" = "ntp.conf" ] || [ "$1" = "chrony.conf" ]
	then
		tmpfile="/tmp/$1"
		Download_File "$SCRIPT_REPO/$1" "$tmpfile"
		if [ ! -f "$SCRIPT_STORAGE_DIR/$1" ]
		then
			Download_File "$SCRIPT_REPO/$1" "$SCRIPT_STORAGE_DIR/$1.default"
			Download_File "$SCRIPT_REPO/$1" "$SCRIPT_STORAGE_DIR/$1"
			Print_Output true "$SCRIPT_STORAGE_DIR/$1 does not exist, downloading now." "$PASS"
		elif [ -f "$SCRIPT_STORAGE_DIR/$1.default" ]
		then
			if ! diff -q "$tmpfile" "$SCRIPT_STORAGE_DIR/$1.default" >/dev/null 2>&1
			then
				Download_File "$SCRIPT_REPO/$1" "$SCRIPT_STORAGE_DIR/$1.default"
				Print_Output true "New default version of $1 downloaded to $SCRIPT_STORAGE_DIR/$1.default, please compare against your $SCRIPT_STORAGE_DIR/$1" "$PASS"
			fi
		else
			Download_File "$SCRIPT_REPO/$1" "$SCRIPT_STORAGE_DIR/$1.default"
			Print_Output true "$SCRIPT_STORAGE_DIR/$1.default does not exist, downloading now. Please compare against your $SCRIPT_STORAGE_DIR/$1" "$PASS"
		fi
		rm -f "$tmpfile"
	elif [ "$1" = "ntpdstats_www.asp" ]
	then
		tmpfile="/tmp/$1"
		if [ -f "$SCRIPT_DIR/$1" ]
		then
			Download_File "$SCRIPT_REPO/$1" "$tmpfile"
			if ! diff -q "$tmpfile" "$SCRIPT_DIR/$1" >/dev/null 2>&1
			then
				Get_WebUI_Page "$SCRIPT_DIR/$1"
				sed -i "\\~$MyWebPage~d" "$TEMP_MENU_TREE"
				rm -f "$SCRIPT_WEBPAGE_DIR/$MyWebPage" 2>/dev/null
				Download_File "$SCRIPT_REPO/$1" "$SCRIPT_DIR/$1"
				Print_Output true "New version of $1 downloaded" "$PASS"
				Mount_WebUI
			fi
			rm -f "$tmpfile"
		else
			Download_File "$SCRIPT_REPO/$1" "$SCRIPT_DIR/$1"
			Print_Output true "New version of $1 downloaded" "$PASS"
			Mount_WebUI
		fi
	elif [ "$1" = "timeserverd" ]
	then
		tmpfile="/tmp/$1"
		if [ -f "$SCRIPT_DIR/$1" ]
		then
			Download_File "$SCRIPT_REPO/$1" "$tmpfile"
			if ! diff -q "$tmpfile" "$SCRIPT_DIR/$1" >/dev/null 2>&1
			then
				Download_File "$SCRIPT_REPO/$1" "$SCRIPT_DIR/$1"
				chmod 0755 "$SCRIPT_DIR/$1"
				Print_Output true "New version of $1 downloaded" "$PASS"
				TimeServer_Customise
			fi
			rm -f "$tmpfile"
		else
			Download_File "$SCRIPT_REPO/$1" "$SCRIPT_DIR/$1"
			chmod 0755 "$SCRIPT_DIR/$1"
			Print_Output true "New version of $1 downloaded" "$PASS"
			TimeServer_Customise
		fi
	elif [ "$1" = "shared-jy.tar.gz" ]
	then
		if [ ! -f "$SHARED_DIR/${1}.md5" ]
		then
			Download_File "$SHARED_REPO/$1" "$SHARED_DIR/$1"
			Download_File "$SHARED_REPO/${1}.md5" "$SHARED_DIR/${1}.md5"
			tar -xzf "$SHARED_DIR/$1" -C "$SHARED_DIR"
			rm -f "$SHARED_DIR/$1"
			Print_Output true "New version of $1 downloaded" "$PASS"
		else
			localmd5="$(cat "$SHARED_DIR/${1}.md5")"
			remotemd5="$(curl -fsL --retry 4 --retry-delay 5 "$SHARED_REPO/${1}.md5")"
			if [ "$localmd5" != "$remotemd5" ]
			then
				Download_File "$SHARED_REPO/$1" "$SHARED_DIR/$1"
				Download_File "$SHARED_REPO/${1}.md5" "$SHARED_DIR/${1}.md5"
				tar -xzf "$SHARED_DIR/$1" -C "$SHARED_DIR"
				rm -f "$SHARED_DIR/$1"
				Print_Output true "New version of $1 downloaded" "$PASS"
			fi
		fi
	else
		return 1
	fi
}

Validate_Number()
{
	if [ "$1" -eq "$1" ] 2>/dev/null; then
		return 0
	else
		return 1
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Nov-15] ##
##----------------------------------------##
Conf_FromSettings()
{
	SETTINGSFILE="/jffs/addons/custom_settings.txt"
	TMPFILE="/tmp/ntpmerlin_settings.txt"

	if [ -f "$SETTINGSFILE" ]
	then
		if [ "$(grep "^ntpmerlin_" $SETTINGSFILE | grep -v "version" -c)" -gt 0 ]
		then
			Print_Output true "Updated settings from WebUI found, merging into $SCRIPT_CONF" "$PASS"
			cp -a "$SCRIPT_CONF" "${SCRIPT_CONF}.bak"
			grep "^ntpmerlin_" "$SETTINGSFILE" | grep -v "version" > "$TMPFILE"
			sed -i "s/^ntpmerlin_//g;s/ /=/g" "$TMPFILE"
			while IFS='' read -r line || [ -n "$line" ]
			do
				SETTINGNAME="$(echo "$line" | cut -f1 -d'=' | awk '{print toupper($1)}')"
				SETTINGVALUE="$(echo "$line" | cut -f2 -d'=')"
				case "$SETTINGNAME:$SETTINGVALUE" in
					OUTPUTTIMEMODE:unix|OUTPUTTIMEMODE:non-unix|STORAGELOCATION:usb|STORAGELOCATION:jffs|TIMESERVER:ntpd|TIMESERVER:chronyd) ;;
					DAYSTOKEEP:*|LASTXRESULTS:*) case "$SETTINGVALUE" in ''|*[!0-9]*) continue ;; esac ;;
					*) continue ;;
				esac
				sed -i "s/$SETTINGNAME=.*/$SETTINGNAME=$SETTINGVALUE/" "$SCRIPT_CONF"
			done < "$TMPFILE"

			grep '^ntpmerlin_version' "$SETTINGSFILE" > "$TMPFILE"
			sed -i "\\~ntpmerlin_~d" "$SETTINGSFILE"
			mv -f "$SETTINGSFILE" "${SETTINGSFILE}.bak"
			cat "${SETTINGSFILE}.bak" "$TMPFILE" > "$SETTINGSFILE"
			rm -f "$TMPFILE"
			rm -f "${SETTINGSFILE}.bak"

			if diff -U0 "$SCRIPT_CONF" "${SCRIPT_CONF}.bak" | grep -qE "[-+]STORAGELOCATION="
			then
				STORAGEtype="$(ScriptStorageLocation check)"
				if [ "$STORAGEtype" = "jffs" ]
				then
				    ## Check if enough free space is available in JFFS ##
				    if _Check_JFFS_SpaceAvailable_ "$SCRIPT_STORAGE_DIR"
				    then ScriptStorageLocation jffs
				    else ScriptStorageLocation usb
				    fi
				elif [ "$STORAGEtype" = "usb" ]
				then
				    ScriptStorageLocation usb
				fi
				Create_Dirs
				Conf_Exists
				Create_Symlinks
			fi
			if diff -U0 "$SCRIPT_CONF" "${SCRIPT_CONF}.bak" | grep -qE "(OUTPUTTIMEMODE=|DAYSTOKEEP=|LASTXRESULTS=)"
			then
				Generate_CSVs
			fi
			if diff -U0 "$SCRIPT_CONF" "${SCRIPT_CONF}.bak" | grep -qE "[-+]TIMESERVER="
			then
				TimeServer "$(TimeServer check)"
			fi
			Print_Output true "Merge of updated settings from WebUI completed successfully" "$PASS"
		else
			Print_Output false "No updated settings from WebUI found, no merge into $SCRIPT_CONF necessary" "$PASS"
		fi
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-04] ##
##----------------------------------------##
Create_Dirs()
{
	if [ ! -d "$SCRIPT_DIR" ]; then
		mkdir -p "$SCRIPT_DIR"
	fi

	if [ ! -d "$SCRIPT_STORAGE_DIR" ]; then
		mkdir -p "$SCRIPT_STORAGE_DIR"
	fi

	if [ ! -d "$CSV_OUTPUT_DIR" ]; then
		mkdir -p "$CSV_OUTPUT_DIR"
	fi

	if [ ! -d "$SHARED_DIR" ]; then
		mkdir -p "$SHARED_DIR"
	fi

	if [ ! -d "$SCRIPT_WEBPAGE_DIR" ]; then
		mkdir -p "$SCRIPT_WEBPAGE_DIR"
	fi

	if [ ! -d "$SCRIPT_WEB_DIR" ]; then
		mkdir -p "$SCRIPT_WEB_DIR"
	fi

	if [ ! -d "$SHARE_TEMP_DIR" ]
	then
		mkdir -m 777 -p "$SHARE_TEMP_DIR"
		export SQLITE_TMPDIR TMPDIR
	fi
}

Create_Symlinks()
{
	rm -rf "${SCRIPT_WEB_DIR:?}/"* 2>/dev/null

	ln -s /tmp/detect_ntpmerlin.js "$SCRIPT_WEB_DIR/detect_ntpmerlin.js" 2>/dev/null
	ln -s "$SCRIPT_STORAGE_DIR/ntpstatstext.js" "$SCRIPT_WEB_DIR/ntpstatstext.js" 2>/dev/null
	ln -s "$SCRIPT_STORAGE_DIR/lastx.csv" "$SCRIPT_WEB_DIR/lastx.htm" 2>/dev/null

	ln -s "$SCRIPT_CONF" "$SCRIPT_WEB_DIR/config.htm" 2>/dev/null

	ln -s "$CSV_OUTPUT_DIR" "$SCRIPT_WEB_DIR/csv" 2>/dev/null

	if [ ! -d "$SHARED_WEB_DIR" ]; then
		ln -s "$SHARED_DIR" "$SHARED_WEB_DIR" 2>/dev/null
	fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Jun-06] ##
##-------------------------------------##
_GetConfigParam_()
{
   if [ $# -eq 0 ] || [ -z "$1" ]
   then echo '' ; return 1 ; fi

   local keyValue  checkFile
   local defValue="$([ $# -eq 2 ] && echo "$2" || echo '')"

   if [ ! -s "$SCRIPT_CONF" ]
   then echo "$defValue" ; return 0 ; fi

   if [ "$(grep -c "^${1}=" "$SCRIPT_CONF")" -gt 1 ]
   then  ## Remove duplicates. Keep ONLY the 1st key ##
       checkFile="${SCRIPT_CONF}.DUPKEY.txt"
       awk "!(/^${1}=/ && dup[/^${1}=/]++)" "$SCRIPT_CONF" > "$checkFile"
       if diff -q "$checkFile" "$SCRIPT_CONF" >/dev/null 2>&1
       then rm -f "$checkFile"
       else mv -f "$checkFile" "$SCRIPT_CONF"
       fi
   fi

   keyValue="$(grep "^${1}=" "$SCRIPT_CONF" | cut -d'=' -f2)"
   echo "${keyValue:=$defValue}"
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-15] ##
##----------------------------------------##
Conf_Exists()
{
	if [ -s "$SCRIPT_CONF" ]
	then
		dos2unix "$SCRIPT_CONF"
		chmod 0644 "$SCRIPT_CONF"
		sed -i -e 's/"//g' "$SCRIPT_CONF"
		if grep -q "OUTPUTDATAMODE" "$SCRIPT_CONF"; then
			sed -i '/OUTPUTDATAMODE/d;' "$SCRIPT_CONF"
		fi
		if ! grep -q "^OUTPUTTIMEMODE=" "$SCRIPT_CONF"; then
			echo "OUTPUTTIMEMODE=unix" >> "$SCRIPT_CONF"
		fi
		if ! grep -q "^DAYSTOKEEP=" "$SCRIPT_CONF"; then
			echo "DAYSTOKEEP=30" >> "$SCRIPT_CONF"
		fi
		if ! grep -q "^LASTXRESULTS=" "$SCRIPT_CONF"; then
			echo "LASTXRESULTS=10" >> "$SCRIPT_CONF"
		fi
		if ! grep -q "^STORAGELOCATION=" "$SCRIPT_CONF"; then
			echo "STORAGELOCATION=jffs" >> "$SCRIPT_CONF"
		fi
		if ! grep -q "^JFFS_MSGLOGTIME=" "$SCRIPT_CONF"; then
			echo "JFFS_MSGLOGTIME=0" >> "$SCRIPT_CONF"
		fi
		if ! grep -q "^TIMESERVER=" "$SCRIPT_CONF"; then
			echo "TIMESERVER=ntpd" >> "$SCRIPT_CONF"
		fi
		return 0
	else
		{
		   echo "OUTPUTTIMEMODE=unix"
		   echo "STORAGELOCATION=jffs"
		   echo "TIMESERVER=ntpd"
		   echo "DAYSTOKEEP=30"
		   echo "LASTXRESULTS=10"
		   echo "JFFS_MSGLOGTIME=0"
		} > "$SCRIPT_CONF"
		return 1
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-19] ##
##----------------------------------------##
Auto_ServiceEvent()
{
	local theScriptFilePath="/jffs/scripts/$SCRIPT_NAME_LOWER"
	case $1 in
		create)
			if [ -s /jffs/scripts/service-event ]
			then
				STARTUPLINECOUNT="$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/service-event)"
				STARTUPLINECOUNTEX="$(grep -cx 'if echo "$2" | /bin/grep -q "'"$SCRIPT_NAME_LOWER"'"; then { '"$theScriptFilePath"' service_event "$@" & }; fi # '"$SCRIPT_NAME" /jffs/scripts/service-event)"

				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ] ; }
				then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/service-event
				fi
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]
				then
					{
					  echo 'if echo "$2" | /bin/grep -q "'"$SCRIPT_NAME_LOWER"'"; then { '"$theScriptFilePath"' service_event "$@" & }; fi # '"$SCRIPT_NAME"
					} >> /jffs/scripts/service-event
				fi
			else
				{
				  echo "#!/bin/sh" ; echo
				  echo 'if echo "$2" | /bin/grep -q "'"$SCRIPT_NAME_LOWER"'"; then { '"$theScriptFilePath"' service_event "$@" & }; fi # '"$SCRIPT_NAME"
				  echo
				} > /jffs/scripts/service-event
			fi
			chmod 0755 /jffs/scripts/service-event
		;;
		delete)
			if [ -s /jffs/scripts/service-event ]
			then
				STARTUPLINECOUNT="$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/service-event)"
				if [ "$STARTUPLINECOUNT" -gt 0 ]
				then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/service-event
				fi
			fi
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-19] ##
##----------------------------------------##
Auto_DNSMASQ()
{
	case $1 in
		create)
			if [ -s /jffs/configs/dnsmasq.conf.add ]
			then
				STARTUPLINECOUNT="$(grep -c '# '"$SCRIPT_NAME" /jffs/configs/dnsmasq.conf.add)"
				STARTUPLINECOUNTEX="$(grep -cx "dhcp-option=lan,42,$(nvram get lan_ipaddr)"' # '"$SCRIPT_NAME" /jffs/configs/dnsmasq.conf.add)"

				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ]; }
				then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/configs/dnsmasq.conf.add
				fi
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]
				then
					{
					  echo
					  echo "dhcp-option=lan,42,$(nvram get lan_ipaddr)"' # '"$SCRIPT_NAME"
					} >> /jffs/configs/dnsmasq.conf.add
					service restart_dnsmasq >/dev/null 2>&1
				fi
			else
				{
				  echo
				  echo "dhcp-option=lan,42,$(nvram get lan_ipaddr)"' # '"$SCRIPT_NAME"
				} >> /jffs/configs/dnsmasq.conf.add
				service restart_dnsmasq >/dev/null 2>&1
			fi
			chmod 0644 /jffs/configs/dnsmasq.conf.add
		;;
		delete)
			if [ -s /jffs/configs/dnsmasq.conf.add ]
			then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/configs/dnsmasq.conf.add)
				if [ "$STARTUPLINECOUNT" -gt 0 ]
				then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/configs/dnsmasq.conf.add
					service restart_dnsmasq >/dev/null 2>&1
				fi
			fi
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-19] ##
##----------------------------------------##
Auto_Startup()
{
	local theScriptFilePath="/jffs/scripts/$SCRIPT_NAME_LOWER"
	case $1 in
		create)
			if [ -s /jffs/scripts/services-start ]
			then
				STARTUPLINECOUNT="$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/services-start)"
				if [ "$STARTUPLINECOUNT" -gt 0 ]
				then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-start
				fi
			fi
			if [ -s /jffs/scripts/post-mount ]
			then
				STARTUPLINECOUNT="$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/post-mount)"
				STARTUPLINECOUNTEX="$(grep -cx '\[ -x "${1}/entware/bin/opkg" \] && \[ -x '"$theScriptFilePath"' \] && '"$theScriptFilePath"' startup "$@" & # '"$SCRIPT_NAME" /jffs/scripts/post-mount)"

				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ] ; }
				then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/post-mount
					STARTUPLINECOUNT=0
				fi
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]
				then
					{
					  echo '[ -x "${1}/entware/bin/opkg" ] && [ -x '"$theScriptFilePath"' ] && '"$theScriptFilePath"' startup "$@" & # '"$SCRIPT_NAME"
					} >> /jffs/scripts/post-mount
				fi
			else
				{
				  echo "#!/bin/sh" ; echo
				  echo '[ -x "${1}/entware/bin/opkg" ] && [ -x '"$theScriptFilePath"' ] && '"$theScriptFilePath"' startup "$@" & # '"$SCRIPT_NAME"
				  echo
				} > /jffs/scripts/post-mount
			fi
			chmod 0755 /jffs/scripts/post-mount
		;;
		delete)
			if [ -s /jffs/scripts/services-start ]
			then
				STARTUPLINECOUNT="$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/services-start)"
				if [ "$STARTUPLINECOUNT" -gt 0 ]
				then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-start
				fi
			fi
			if [ -s /jffs/scripts/post-mount ]
			then
				STARTUPLINECOUNT="$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/post-mount)"
				if [ "$STARTUPLINECOUNT" -gt 0 ]
				then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/post-mount
				fi
			fi
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-19] ##
##----------------------------------------##
Auto_NAT()
{
	case $1 in
		create)
			if [ -s /jffs/scripts/nat-start ]
			then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/nat-start)
				STARTUPLINECOUNTEX=$(grep -cx "/jffs/scripts/$SCRIPT_NAME_LOWER ntpredirect"' # '"$SCRIPT_NAME" /jffs/scripts/nat-start)

				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ]; }
				then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/nat-start
				fi
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]
				then
					{
					  echo "/jffs/scripts/$SCRIPT_NAME_LOWER ntpredirect"' # '"$SCRIPT_NAME"
					  echo
					} >> /jffs/scripts/nat-start
				fi
			else
				{
				  echo "#!/bin/sh" ; echo
				  echo "/jffs/scripts/$SCRIPT_NAME_LOWER ntpredirect"' # '"$SCRIPT_NAME"
				  echo
				} > /jffs/scripts/nat-start
			fi
			chmod 0755 /jffs/scripts/nat-start
		;;
		delete)
			if [ -s /jffs/scripts/nat-start ]
			then
				STARTUPLINECOUNT="$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/nat-start)"
				if [ "$STARTUPLINECOUNT" -gt 0 ]
				then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/nat-start
				fi
			fi
		;;
		check)
			if [ -s /jffs/scripts/nat-start ]
			then
				STARTUPLINECOUNT="$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/nat-start)"
				if [ "$STARTUPLINECOUNT" -gt 0 ]
				then
					return 0
				else
					return 1
				fi
			else
				return 1
			fi
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-29] ##
##----------------------------------------##
Auto_Cron()
{
	local theScriptFilePath="/jffs/scripts/$SCRIPT_NAME_LOWER"
	case $1 in
		create)
			STARTUPLINECOUNT="$(cru l | grep -c "#${SCRIPT_NAME}#")"
			if [ "$STARTUPLINECOUNT" -gt 0 ]
			then
				cru d "${SCRIPT_NAME}"
			fi

			STARTUPLINECOUNTGEN="$(cru l | grep -c "${SCRIPT_NAME}_generate")"
			STARTUPLINECOUNTEXGEN="$(cru l | grep "${SCRIPT_NAME}_generate" | grep -c "^[*]/10 [*] [*]")"
			if [ "$STARTUPLINECOUNTGEN" -gt 0 ] && [ "$STARTUPLINECOUNTEXGEN" -eq 0 ]
			then
				cru d "${SCRIPT_NAME}_generate"
				STARTUPLINECOUNTGEN="$(cru l | grep -c "${SCRIPT_NAME}_generate")"
			fi
			if [ "$STARTUPLINECOUNTGEN" -eq 0 ]
			then
				cru a "${SCRIPT_NAME}_generate" "*/10 * * * * $theScriptFilePath generate"
			fi

			STARTUPLINECOUNTTRIM="$(cru l | grep -c "${SCRIPT_NAME}_trimDB")"
			STARTUPLINECOUNTEXTRIM="$(cru l | grep "${SCRIPT_NAME}_trimDB" | grep -c "^$defTrimDB_Mins $defTrimDB_Hour [*] [*]")"
			if [ "$STARTUPLINECOUNTTRIM" -gt 0 ] && [ "$STARTUPLINECOUNTEXTRIM" -eq 0 ]
			then
				cru d "${SCRIPT_NAME}_trimDB"
				STARTUPLINECOUNTTRIM="$(cru l | grep -c "${SCRIPT_NAME}_trimDB")"
			fi
			if [ "$STARTUPLINECOUNTTRIM" -eq 0 ]
			then
				cru a "${SCRIPT_NAME}_trimDB" "$defTrimDB_Mins $defTrimDB_Hour * * * $theScriptFilePath trimdb"
			fi
		;;
		delete)
			STARTUPLINECOUNT="$(cru l | grep -c "#${SCRIPT_NAME}#")"
			if [ "$STARTUPLINECOUNT" -gt 0 ]
			then
				cru d "$SCRIPT_NAME"
			fi
			STARTUPLINECOUNTGEN="$(cru l | grep -c "#${SCRIPT_NAME}_generate#")"
			if [ "$STARTUPLINECOUNTGEN" -gt 0 ]
			then
				cru d "${SCRIPT_NAME}_generate"
			fi
			STARTUPLINECOUNTTRIM="$(cru l | grep -c "#${SCRIPT_NAME}_trimDB#")"
			if [ "$STARTUPLINECOUNTTRIM" -gt 0 ]
			then
				cru d "${SCRIPT_NAME}_trimDB"
			fi
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-04] ##
##----------------------------------------##
Download_File()
{ /usr/sbin/curl -LSs --retry 4 --retry-delay 5 --retry-connrefused "$1" -o "$2" ; }

NTP_Redirect()
{
	case $1 in
		create)
			for ACTION in -D -I
			do
				iptables -t nat "$ACTION" PREROUTING -i br0 -p udp --dport 123 -j DNAT --to "$(nvram get lan_ipaddr)" 2>/dev/null
				iptables -t nat "$ACTION" PREROUTING -i br0 -p tcp --dport 123 -j DNAT --to "$(nvram get lan_ipaddr)" 2>/dev/null
				
				## drop attempts for clients trying to avoid redirect ##
				if [ "$ACTION" = "-I" ]
				then
					FWRDSTART="$(iptables -nvL FORWARD --line | grep -E "all.*state RELATED,ESTABLISHED" | tail -1 | awk '{print $1}')"
					if [ -n "$(iptables -nvL FORWARD --line | grep -E "YazFiFORWARD" | tail -1 | awk '{print $1}')" ]; then
						FWRDSTART="$(($(iptables -nvL FORWARD --line | grep -E "YazFiFORWARD" | tail -1 | awk '{print $1}') + 1))"
					fi
					iptables "$ACTION" FORWARD "$FWRDSTART" -i br0 -p tcp --dport 123 -j REJECT 2>/dev/null
					iptables "$ACTION" FORWARD "$FWRDSTART" -i br0 -p udp --dport 123 -j REJECT 2>/dev/null
				fi
				ip6tables "$ACTION" FORWARD -i br0 -p tcp --dport 123 -j REJECT 2>/dev/null
				ip6tables "$ACTION" FORWARD -i br0 -p udp --dport 123 -j REJECT 2>/dev/null
				##
			done
			Auto_DNSMASQ create 2>/dev/null
		;;
		delete)
			iptables -t nat -D PREROUTING -i br0 -p udp --dport 123 -j DNAT --to "$(nvram get lan_ipaddr)" 2>/dev/null
			iptables -t nat -D PREROUTING -i br0 -p tcp --dport 123 -j DNAT --to "$(nvram get lan_ipaddr)" 2>/dev/null
			
			iptables -D FORWARD -i br0 -p tcp --dport 123 -j REJECT 2>/dev/null
			iptables -D FORWARD -i br0 -p udp --dport 123 -j REJECT 2>/dev/null
			ip6tables -D FORWARD -i br0 -p tcp --dport 123 -j REJECT 2>/dev/null
			ip6tables -D FORWARD -i br0 -p udp --dport 123 -j REJECT 2>/dev/null
			
			Auto_DNSMASQ delete 2>/dev/null
		;;
	esac
}

NTP_Firmware_Check()
{
	ENABLED_NTPD="$(nvram get ntpd_enable)"
	if ! Validate_Number "$ENABLED_NTPD"; then ENABLED_NTPD=0; fi
	
	if [ "$ENABLED_NTPD" -eq 1 ]
	then
		Print_Output true "Built-in ntpd is enabled and will conflict, it will be disabled" "$WARN"
		nvram set ntpd_enable=0
		nvram set ntpd_server_redir=0
		nvram commit
		service restart_ntpd
		service restart_firewall
		return 1
	else
		return 0
	fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Feb-15] ##
##-------------------------------------##
_Check_WebGUI_Page_Exists_()
{
   local webPageStr  webPageFile  theWebPage

   if [ ! -f "$TEMP_MENU_TREE" ]
   then echo "NONE" ; return 1 ; fi

   theWebPage="NONE"
   webPageStr="$(grep -E -m1 "^$webPageLineRegExp" "$TEMP_MENU_TREE")"
   if [ -n "$webPageStr" ]
   then
       webPageFile="$(echo "$webPageStr" | grep -owE "$webPageFileRegExp" | head -n1)"
       if [ -n "$webPageFile" ] && [ -s "${SCRIPT_WEBPAGE_DIR}/$webPageFile" ]
       then theWebPage="$webPageFile" ; fi
   fi
   echo "$theWebPage"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-19] ##
##----------------------------------------##
Get_WebUI_Page()
{
	if [ $# -eq 0 ] || [ -z "$1" ] || [ ! -s "$1" ]
	then MyWebPage="NONE" ; return 1 ; fi

	local webPageFile  webPagePath

	MyWebPage="$(_Check_WebGUI_Page_Exists_)"

	for indx in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
	do
		webPageFile="user${indx}.asp"
		webPagePath="${SCRIPT_WEBPAGE_DIR}/$webPageFile"

		if [ -s "$webPagePath" ] && \
		   [ "$(md5sum < "$1")" = "$(md5sum < "$webPagePath")" ]
		then
			MyWebPage="$webPageFile"
			break
		elif [ "$MyWebPage" = "NONE" ] && [ ! -s "$webPagePath" ]
		then
			MyWebPage="$webPageFile"
		fi
	done
}

### function based on @dave14305's FlexQoS webconfigpage function ###
##----------------------------------------##
## Modified by Martinski W. [2025-Feb-15] ##
##----------------------------------------##
Get_WebUI_URL()
{
	local urlPage  urlProto  urlDomain  urlPort  lanPort

	if [ ! -f "$TEMP_MENU_TREE" ]
	then
		echo "**ERROR**: WebUI page NOT mounted"
		return 1
	fi

	urlPage="$(sed -nE "/$SCRIPT_NAME/ s/.*url\: \"(user[0-9]+\.asp)\".*/\1/p" "$TEMP_MENU_TREE")"

	if [ "$(nvram get http_enable)" -eq 1 ]; then
		urlProto="https"
	else
		urlProto="http"
	fi
	if [ -n "$(nvram get lan_domain)" ]; then
		urlDomain="$(nvram get lan_hostname).$(nvram get lan_domain)"
	else
		urlDomain="$(nvram get lan_ipaddr)"
	fi

	lanPort="$(nvram get ${urlProto}_lanport)"
	if [ "$lanPort" -eq 80 ] || [ "$lanPort" -eq 443 ]
	then
		urlPort=""
	else
		urlPort=":$lanPort"
	fi

	if echo "$urlPage" | grep -qE "^${webPageFileRegExp}$" && \
	   [ -s "${SCRIPT_WEBPAGE_DIR}/$urlPage" ]
	then
		echo "${urlProto}://${urlDomain}${urlPort}/${urlPage}" | tr "A-Z" "a-z"
	else
		echo "**ERROR**: WebUI page NOT found"
	fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Feb-16] ##
##-------------------------------------##
_CreateMenuAddOnsSection_()
{
   if grep -qE "^${webPageMenuAddons}$" "$TEMP_MENU_TREE" && \
      grep -qE "${webPageHelpSupprt}$" "$TEMP_MENU_TREE"
   then return 0 ; fi

   lineinsBefore="$(($(grep -n "^exclude:" "$TEMP_MENU_TREE" | cut -f1 -d':') - 1))"

   sed -i "$lineinsBefore""i\
${BEGIN_MenuAddOnsTag}\n\
,\n{\n\
${webPageMenuAddons}\n\
index: \"menu_Addons\",\n\
tab: [\n\
{url: \"javascript:var helpwindow=window.open('\/ext\/shared-jy\/redirect.htm')\", ${webPageHelpSupprt}\n\
{url: \"NULL\", tabName: \"__INHERIT__\"}\n\
]\n}\n\
${ENDIN_MenuAddOnsTag}" "$TEMP_MENU_TREE"
}

### locking mechanism code credit to Martineau (@MartineauUK) ###
##----------------------------------------##
## Modified by Martinski W. [2025-Jun-20] ##
##----------------------------------------##
Mount_WebUI()
{
	Print_Output true "Mounting WebUI tab for $SCRIPT_NAME" "$PASS"

	LOCKFILE=/tmp/addonwebui.lock
	FD=386
	eval exec "$FD>$LOCKFILE"
	flock -x "$FD"
	Get_WebUI_Page "$SCRIPT_DIR/ntpdstats_www.asp"
	if [ "$MyWebPage" = "NONE" ]
	then
		Print_Output true "**ERROR** Unable to mount $SCRIPT_NAME WebUI page." "$CRIT"
		flock -u "$FD"
		return 1
	fi
	cp -fp "$SCRIPT_DIR/ntpdstats_www.asp" "$SCRIPT_WEBPAGE_DIR/$MyWebPage"
	echo "$SCRIPT_NAME" > "$SCRIPT_WEBPAGE_DIR/$(echo "$MyWebPage" | cut -f1 -d'.').title"

	if [ "$(/bin/uname -o)" = "ASUSWRT-Merlin" ]
	then
		if [ ! -f /tmp/index_style.css ]; then
			cp -fp /www/index_style.css /tmp/
		fi

		if ! grep -q '.menu_Addons' /tmp/index_style.css
		then
			echo ".menu_Addons { background: url(ext/shared-jy/addons.png); }" >> /tmp/index_style.css
		fi

		umount /www/index_style.css 2>/dev/null
		mount -o bind /tmp/index_style.css /www/index_style.css

		if [ ! -f "$TEMP_MENU_TREE" ]; then
			cp -fp /www/require/modules/menuTree.js "$TEMP_MENU_TREE"
		fi
		sed -i "\\~$MyWebPage~d" "$TEMP_MENU_TREE"

		_CreateMenuAddOnsSection_

		sed -i "/url: \"javascript:var helpwindow=window.open('\/ext\/shared-jy\/redirect.htm'/i {url: \"$MyWebPage\", tabName: \"$SCRIPT_NAME\"}," "$TEMP_MENU_TREE"

		umount /www/require/modules/menuTree.js 2>/dev/null
		mount -o bind "$TEMP_MENU_TREE" /www/require/modules/menuTree.js
	fi
	flock -u "$FD"

	Print_Output true "Mounted $SCRIPT_NAME WebUI page as $MyWebPage" "$PASS"
}

##-------------------------------------##
## Added by Martinski W. [2025-Feb-11] ##
##-------------------------------------##
_CheckFor_WebGUI_Page_()
{
   if [ "$(_Check_WebGUI_Page_Exists_)" = "NONE" ]
   then Mount_WebUI ; fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Aug-03] ##
##----------------------------------------##
TimeServer_Customise()
{
	local TIMESERVER_ID  initTimeServerPath

	TIMESERVER_ID="$(TimeServer check)"
	initTimeServerPath="/opt/etc/init.d/S77$TIMESERVER_ID"

	if [ -f /opt/etc/init.d/S77ntpd ]
	then
		/opt/etc/init.d/S77ntpd stop >/dev/null 2>&1
		sleep 2 ; killall -q ntpd ; sleep 1
		rm -f /opt/etc/init.d/S77ntpd
	fi
	if [ -f /opt/etc/init.d/S77chronyd ]
	then
		/opt/etc/init.d/S77chronyd stop >/dev/null 2>&1
		sleep 2 ; killall -q chronyd ; sleep 1
		rm -f /opt/etc/init.d/S77chronyd
	fi

	Download_File "$SCRIPT_REPO/S77$TIMESERVER_ID" "$initTimeServerPath"
	chmod a+x "$initTimeServerPath"

	if [ "$TIMESERVER_ID" = "chronyd" ]
	then
		mkdir -p /opt/var/lib/chrony
		mkdir -p /opt/var/run/chrony
		chmod -R 770 /opt/var/lib/chrony
		chmod -R 770 /opt/var/run/chrony
		chown -R nobody:nobody /opt/var/lib/chrony
		chown -R nobody:nobody /opt/var/run/chrony
		[ ! -L /opt/etc/passwd ] && \
		ln -snf /etc/passwd /opt/etc/passwd 2>/dev/null
	fi
	"$initTimeServerPath" restart
}

##-------------------------------------##
## Added by Martinski W. [2025-Jul-30] ##
##-------------------------------------##
TimeServer_ServiceCheck()
{
    local runFullCheck=true  TIMESERVER_ID
    local initTimeServerPath  saveTimeServerPath

    if [ $# -gt 0 ] && [ -n "$1" ] && \
       echo "$1" | grep -qE "^(true|false)$"
    then runFullCheck="$1" ; fi

    "$runFullCheck" && Entware_Ready
    TIMESERVER_ID="$(TimeServer check)"
    initTimeServerPath="/opt/etc/init.d/S77$TIMESERVER_ID"
    saveTimeServerPath="$SCRIPT_DIR/S77$TIMESERVER_ID"

    if "$runFullCheck" || [ ! -s "$saveTimeServerPath" ]
    then
        Update_File "S77$TIMESERVER_ID" >/dev/null 2>&1
    else
        # Make sure we have the ntpMerlin version #
        if [ -s "$saveTimeServerPath" ] && [ -s "$initTimeServerPath" ] && \
           ! diff -q "$initTimeServerPath" "$saveTimeServerPath" >/dev/null 2>&1 
        then
            "$initTimeServerPath" stop >/dev/null 2>&1
            sleep 2 ; killall -q "$TIMESERVER_ID"
            cp -fp "$saveTimeServerPath" "$initTimeServerPath"
            chmod a+x "$initTimeServerPath"
        fi
        if [ -z "$(pidof "$TIMESERVER_ID")" ]
        then "$initTimeServerPath" restart
        fi

        # Stop & remove extraneous service script #
        if [ "$TIMESERVER_ID" = "chronyd" ] && \
           [ -f /opt/etc/init.d/S77ntpd ]
        then
            /opt/etc/init.d/S77ntpd stop >/dev/null 2>&1
            sleep 2 ; killall -q ntpd ; sleep 1
            rm -f /opt/etc/init.d/S77ntpd
        elif [ "$TIMESERVER_ID" = "ntpd" ] && \
             [ -f /opt/etc/init.d/S77chronyd ]
        then
            /opt/etc/init.d/S77chronyd stop >/dev/null 2>&1
            sleep 2 ; killall -q chronyd ; sleep 1
            rm -f /opt/etc/init.d/S77chronyd
        fi
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-06] ##
##----------------------------------------##
ScriptStorageLocation()
{
	case "$1" in
		usb)
			printf "Please wait..."
			TIMESERVER_NAME="$(TimeServer check)"
			sed -i 's/^STORAGELOCATION.*$/STORAGELOCATION=usb/' "$SCRIPT_CONF"
			mkdir -p "/opt/share/$SCRIPT_NAME_LOWER.d/"
			rm -f "/jffs/addons/$SCRIPT_NAME_LOWER.d/ntpdstats.db-shm"
			rm -f "/jffs/addons/$SCRIPT_NAME_LOWER.d/ntpdstats.db-wal"
			if [ -d "/opt/share/$SCRIPT_NAME_LOWER.d/csv" ] && \
			   [ -d "/jffs/addons/$SCRIPT_NAME_LOWER.d/csv" ]
			then rm -fr "/opt/share/$SCRIPT_NAME_LOWER.d/csv"
			fi
			mv -f "/jffs/addons/$SCRIPT_NAME_LOWER.d/csv" "/opt/share/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME_LOWER.d/config" "/opt/share/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME_LOWER.d/config.bak" "/opt/share/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME_LOWER.d/ntpstatstext.js" "/opt/share/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME_LOWER.d/lastx.csv" "/opt/share/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME_LOWER.d"/ntpdstats.db* "/opt/share/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME_LOWER.d/ntp.conf" "/opt/share/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME_LOWER.d/ntp.conf.default" "/opt/share/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME_LOWER.d/chrony.conf" "/opt/share/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME_LOWER.d/chrony.conf.default" "/opt/share/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME_LOWER.d/.chronyugraded" "/opt/share/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME_LOWER.d/.indexcreated" "/opt/share/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			"/opt/etc/init.d/S77$TIMESERVER_NAME" restart >/dev/null 2>&1
			SCRIPT_CONF="/opt/share/${SCRIPT_NAME_LOWER}.d/config"
			NTPDSTATS_DB="/opt/share/${SCRIPT_NAME_LOWER}.d/ntpdstats.db"
			CSV_OUTPUT_DIR="/opt/share/${SCRIPT_NAME_LOWER}.d/csv"
			ScriptStorageLocation load true
			sleep 2
			;;
		jffs)
			printf "Please wait..."
			TIMESERVER_NAME="$(TimeServer check)"
			sed -i 's/^STORAGELOCATION.*$/STORAGELOCATION=jffs/' "$SCRIPT_CONF"
			mkdir -p "/jffs/addons/$SCRIPT_NAME_LOWER.d/"
			if [ -d "/opt/share/$SCRIPT_NAME_LOWER.d/csv" ] && \
			   [ -d "/jffs/addons/$SCRIPT_NAME_LOWER.d/csv" ]
			then rm -fr "/jffs/addons/$SCRIPT_NAME_LOWER.d/csv"
			fi
			mv -f "/opt/share/$SCRIPT_NAME_LOWER.d/csv" "/jffs/addons/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME_LOWER.d/config" "/jffs/addons/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME_LOWER.d/config.bak" "/jffs/addons/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME_LOWER.d/ntpstatstext.js" "/jffs/addons/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME_LOWER.d/lastx.csv" "/jffs/addons/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME_LOWER.d"/ntpdstats.db* "/jffs/addons/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME_LOWER.d/ntp.conf" "/jffs/addons/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME_LOWER.d/ntp.conf.default" "/jffs/addons/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME_LOWER.d/chrony.conf" "/jffs/addons/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME_LOWER.d/chrony.conf.default" "/jffs/addons/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME_LOWER.d/.chronyugraded" "/jffs/addons/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME_LOWER.d/.indexcreated" "/jffs/addons/$SCRIPT_NAME_LOWER.d/" 2>/dev/null
			"/opt/etc/init.d/S77$TIMESERVER_NAME" restart >/dev/null 2>&1
			SCRIPT_CONF="/jffs/addons/${SCRIPT_NAME_LOWER}.d/config"
			NTPDSTATS_DB="/jffs/addons/${SCRIPT_NAME_LOWER}.d/ntpdstats.db"
			CSV_OUTPUT_DIR="/jffs/addons/${SCRIPT_NAME_LOWER}.d/csv"
			ScriptStorageLocation load true
			sleep 2
			;;
		check)
			STORAGELOCATION="$(_GetConfigParam_ STORAGELOCATION jffs)"
			echo "$STORAGELOCATION"
			;;
		load)
			STORAGELOCATION="$(ScriptStorageLocation check)"
			if [ "$STORAGELOCATION" = "usb" ]
			then
				SCRIPT_STORAGE_DIR="/opt/share/${SCRIPT_NAME_LOWER}.d"
			elif [ "$STORAGELOCATION" = "jffs" ]
			then
				SCRIPT_STORAGE_DIR="/jffs/addons/${SCRIPT_NAME_LOWER}.d"
			fi
			chmod 777 "$SCRIPT_STORAGE_DIR"
			NTPDSTATS_DB="$SCRIPT_STORAGE_DIR/ntpdstats.db"
			CSV_OUTPUT_DIR="$SCRIPT_STORAGE_DIR/csv"
			if [ $# -gt 1 ] && [ "$2" = "true" ]
			then _UpdateJFFS_FreeSpaceInfo_ ; fi
			;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-06] ##
##----------------------------------------##
OutputTimeMode()
{
	case "$1" in
		unix)
			sed -i 's/^OUTPUTTIMEMODE=.*$/OUTPUTTIMEMODE=unix/' "$SCRIPT_CONF"
			Generate_CSVs
		;;
		non-unix)
			sed -i 's/^OUTPUTTIMEMODE=.*$/OUTPUTTIMEMODE=non-unix/' "$SCRIPT_CONF"
			Generate_CSVs
		;;
		check)
			OUTPUTTIMEMODE="$(_GetConfigParam_ OUTPUTTIMEMODE unix)"
			echo "$OUTPUTTIMEMODE"
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2026-Mar-15] ##
##----------------------------------------##
TimeServer()
{
	case "$1" in
		ntpd)
			printf "Please wait...\n"
			sed -i 's/^TIMESERVER=.*$/TIMESERVER=ntpd/' "$SCRIPT_CONF"
			/opt/etc/init.d/S77chronyd stop >/dev/null 2>&1
			sleep 2 ; killall -q chronyd ; sleep 1
			rm -f /opt/etc/init.d/S77chronyd
			if [ ! -f /opt/sbin/ntpd ] && [ -x /opt/bin/opkg ]
			then
				opkg update
				opkg install ntp-utils
				opkg install ntpd
			fi
			Update_File ntp.conf >/dev/null 2>&1
			Update_File S77ntpd >/dev/null 2>&1

			# Double-check that the Entware package was installed #
			if [ -x /opt/bin/opkg ] && [ ! -x /opt/sbin/ntpd ]
			then
				Print_Output true "**ERROR** The 'ntpd' Entware package is NOT installed." "$CRIT"
			fi
		;;
		chronyd)
			printf "Please wait...\n"
			sed -i 's/^TIMESERVER=.*$/TIMESERVER=chronyd/' "$SCRIPT_CONF"
			/opt/etc/init.d/S77ntpd stop >/dev/null 2>&1
			sleep 2 ; killall -q ntpd ; sleep 1
			rm -f /opt/etc/init.d/S77ntpd
			if [ ! -f /opt/sbin/chronyd ] && [ -x /opt/bin/opkg ]
			then
				opkg update
				if [ -n "$(opkg info chrony-nts)" ]
				then
					opkg install chrony-nts
					touch "$SCRIPT_STORAGE_DIR/.chronyugraded"
				else
					opkg install chrony
					touch "$SCRIPT_STORAGE_DIR/.chronyugraded"
				fi
			fi
			Update_File chrony.conf >/dev/null 2>&1
			Update_File S77chronyd >/dev/null 2>&1

			# Double-check that the Entware package was installed #
			if [ -x /opt/bin/opkg ] && [ ! -x /opt/sbin/chronyd ]
			then
				Print_Output true "**ERROR** The 'chrony' Entware package is NOT installed." "$CRIT"
			fi
		;;
		check)
			TIMESERVER="$(_GetConfigParam_ TIMESERVER ntpd)"
			echo "$TIMESERVER"
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-06] ##
##----------------------------------------##
DaysToKeep()
{
	local MINvalue=15  MAXvalue=365  #Days#
	case "$1" in
		update)
			daysToKeep="$(DaysToKeep check)"
			exitLoop=false
			while true
			do
				ScriptHeader
				printf " ${BOLD}Current number of days to keep data: ${GRNct}${daysToKeep}${CLRct}\n\n"
				printf " ${BOLD}Please enter the maximum number of days\n"
				printf " to keep the data for [${GRNct}${MINvalue}-${MAXvalue}${CLRct}] (e=Exit):${CLRct}  "
				read -r daystokeep_choice
				if [ -z "$daystokeep_choice" ] && \
				   echo "$daysToKeep" | grep -qE "^([1-9][0-9]{1,2})$" && \
				   [ "$daysToKeep" -ge "$MINvalue" ] && [ "$daysToKeep" -le "$MAXvalue" ]
				then
					exitLoop=true
					break
				elif [ "$daystokeep_choice" = "e" ]
				then
					exitLoop=true
					break
				elif ! Validate_Number "$daystokeep_choice"
				then
					printf "\n${ERR}Please enter a valid number [${MINvalue}-${MAXvalue}].${CLRct}\n"
					PressEnter
				elif [ "$daystokeep_choice" -lt "$MINvalue" ] || [ "$daystokeep_choice" -gt "$MAXvalue" ]
				then
					printf "\n${ERR}Please enter a number between ${MINvalue} and ${MAXvalue}.${CLRct}\n"
					PressEnter
				else
					daysToKeep="$daystokeep_choice"
					break
				fi
			done

			if "$exitLoop"
			then
				echo ; return 1
			else
				DAYSTOKEEP="$daysToKeep"
				sed -i 's/^DAYSTOKEEP=.*$/DAYSTOKEEP='"$DAYSTOKEEP"'/' "$SCRIPT_CONF"
				echo ; return 0
			fi
		;;
		check)
			DAYSTOKEEP="$(_GetConfigParam_ DAYSTOKEEP 30)"
			echo "$DAYSTOKEEP"
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-06] ##
##----------------------------------------##
LastXResults()
{
	local MINvalue=5  MAXvalue=100  #Results#
	case "$1" in
		update)
			lastXResults="$(LastXResults check)"
			exitLoop=false
			while true
			do
				ScriptHeader
				printf " ${BOLD}Current number of results to display: ${GRNct}${lastXResults}${CLRct}\n\n"
				printf " ${BOLD}Please enter the maximum number of results\n"
				printf " to display in the WebUI [${GRNct}${MINvalue}-${MAXvalue}${CLRct}] (e=Exit):${CLRct}  "
				read -r lastx_choice
				if [ -z "$lastx_choice" ] && \
				   echo "$lastXResults" | grep -qE "^([1-9][0-9]{0,2})$" && \
				   [ "$lastXResults" -ge "$MINvalue" ] && [ "$lastXResults" -le "$MAXvalue" ]
				then
					exitLoop=true
					break
				elif [ "$lastx_choice" = "e" ]
				then
					exitLoop=true
					break
				elif ! Validate_Number "$lastx_choice"
				then
					printf "\n${ERR}Please enter a valid number [${MINvalue}-${MAXvalue}].${CLRct}\n"
					PressEnter
				elif [ "$lastx_choice" -lt "$MINvalue" ] || [ "$lastx_choice" -gt "$MAXvalue" ]
				then
					printf "\n${ERR}Please enter a number between ${MINvalue} and ${MAXvalue}.${CLRct}\n"
					PressEnter
				else
					lastXResults="$lastx_choice"
					break
				fi
			done

			if "$exitLoop"
			then
				echo ; return 1
			else
				LASTXRESULTS="$lastXResults"
				sed -i 's/^LASTXRESULTS=.*$/LASTXRESULTS='"$LASTXRESULTS"'/' "$SCRIPT_CONF"
				Generate_LastXResults
				echo ; return 0
			fi
		;;
		check)
			LASTXRESULTS="$(_GetConfigParam_ LASTXRESULTS 10)"
			echo "$LASTXRESULTS"
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-04] ##
##----------------------------------------##
WriteStats_ToJS()
{
	if [ $# -lt 4 ] ; then return 1 ; fi

	if [ -f "$2" ]
	then
	    sed -i -e '/^}/d;/^function/d;/^document.getElementById/d;/^databaseResetDone/d;' "$2"
	    awk 'NF' "$2" > "${2}.tmp"
	    mv -f "${2}.tmp" "$2"
	fi
	printf "\nfunction %s(){\n" "$3" >> "$2"
	html='document.getElementById("'"$4"'").innerHTML="'

	while IFS='' read -r line || [ -n "$line" ]
	do html="${html}${line}"
	done < "$1"
	html="$html"'"'

	if [ $# -lt 5 ] || [ -z "$5" ]
	then printf "%s\n}\n" "$html" >> "$2"
	else printf "%s;\n%s\n}\n" "$html" "$5" >> "$2"
	fi
}

##----------------------------------------------------------------------
# $1 fieldname $2 tablename $3 frequency (hours) $4 length (days) 
# $5 outputfile $6 outputfrequency $7 sqlfile $8 timestamp
##----------------------------------------------------------------------
##----------------------------------------##
## Modified by Martinski W. [2025-Jan-04] ##
##----------------------------------------##
WriteSql_ToFile()
{
	timenow="$8"
	maxcount="$(echo "$3" "$4" | awk '{printf ((24*$2)/$1)}')"

	if ! echo "$5" | grep -q "day"
	then
		{
		   echo ".mode csv"
		   echo ".headers on"
		   echo ".output ${5}_${6}.htm"
		   echo "PRAGMA temp_store=1;"
		   echo "SELECT '$1' Metric,Min(strftime('%s',datetime(strftime('%Y-%m-%d %H:00:00',datetime([Timestamp],'unixepoch'))))) Time,IFNULL(printf('%f',Avg($1)),'NaN') Value FROM $2 WHERE ([Timestamp] >= strftime('%s',datetime($timenow,'unixepoch','-$maxcount hour'))) GROUP BY strftime('%m',datetime([Timestamp],'unixepoch')),strftime('%d',datetime([Timestamp],'unixepoch')),strftime('%H',datetime([Timestamp],'unixepoch')) ORDER BY [Timestamp] DESC;"
		} > "$7"
	else
		{
		   echo ".mode csv"
		   echo ".headers on"
		   echo ".output ${5}_${6}.htm"
		   echo "PRAGMA temp_store=1;"
		   echo "SELECT '$1' Metric,Max(strftime('%s',datetime([Timestamp],'unixepoch','localtime','start of day','utc'))) Time,IFNULL(printf('%f',Avg($1)),'NaN') Value FROM $2 WHERE ([Timestamp] > strftime('%s',datetime($timenow,'unixepoch','localtime','start of day','utc','+1 day','-$maxcount day'))) GROUP BY strftime('%m',datetime([Timestamp],'unixepoch','localtime')),strftime('%d',datetime([Timestamp],'unixepoch','localtime')) ORDER BY [Timestamp] DESC;"
		} > "$7"
	fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Jan-04] ##
##-------------------------------------##
_GetFileSize_()
{
   local sizeUnits  sizeInfo  fileSize
   if [ $# -eq 0 ] || [ -z "$1" ] || [ ! -s "$1" ]
   then echo 0; return 1 ; fi

   if [ $# -lt 2 ] || [ -z "$2" ] || \
      ! echo "$2" | grep -qE "^(B|KB|MB|GB|HR|HRx)$"
   then sizeUnits="B" ; else sizeUnits="$2" ; fi

   _GetNum_() { printf "%.1f" "$(echo "$1" | awk "{print $1}")" ; }

   case "$sizeUnits" in
       B|KB|MB|GB)
           fileSize="$(ls -1l "$1" | awk -F ' ' '{print $3}')"
           case "$sizeUnits" in
               KB) fileSize="$(_GetNum_ "($fileSize / $oneKByte)")" ;;
               MB) fileSize="$(_GetNum_ "($fileSize / $oneMByte)")" ;;
               GB) fileSize="$(_GetNum_ "($fileSize / $oneGByte)")" ;;
           esac
           echo "$fileSize"
           ;;
       HR|HRx)
           fileSize="$(ls -1lh "$1" | awk -F ' ' '{print $3}')"
           sizeInfo="${fileSize}B"
           if [ "$sizeUnits" = "HR" ]
           then echo "$sizeInfo" ; return 0 ; fi
           sizeUnits="$(echo "$sizeInfo" | tr -d '.0-9')"
           case "$sizeUnits" in
               MB) fileSize="$(_GetFileSize_ "$1" KB)"
                   sizeInfo="$sizeInfo [${fileSize}KB]"
                   ;;
               GB) fileSize="$(_GetFileSize_ "$1" MB)"
                   sizeInfo="$sizeInfo [${fileSize}MB]"
                   ;;
           esac
           echo "$sizeInfo"
           ;;
       *) echo 0 ;;
   esac
   return 0
}

##-------------------------------------##
## Added by Martinski W. [2025-Jan-04] ##
##-------------------------------------##
_Get_JFFS_Space_()
{
   local typex  total  usedx  freex  totalx
   local sizeUnits  sizeType  sizeInfo  sizeNum
   local jffsMountStr  jffsUsageStr  percentNum  percentStr

   if [ $# -lt 1 ] || [ -z "$1" ] || \
      ! echo "$1" | grep -qE "^(ALL|USED|FREE)$"
   then sizeType="ALL" ; else sizeType="$1" ; fi

   if [ $# -lt 2 ] || [ -z "$2" ] || \
      ! echo "$2" | grep -qE "^(KB|KBP|MBP|GBP|HR|HRx)$"
   then sizeUnits="KB" ; else sizeUnits="$2" ; fi

   _GetNum_() { printf "%.2f" "$(echo "$1" | awk "{print $1}")" ; }

   jffsMountStr="$(mount | grep '/jffs')"
   jffsUsageStr="$(df -kT /jffs | grep -E '.*[[:blank:]]+/jffs$')"

   if [ -z "$jffsMountStr" ] || [ -z "$jffsUsageStr" ]
   then echo "**ERROR**: JFFS is *NOT* mounted." ; return 1
   fi
   if echo "$jffsMountStr" | grep -qE "[[:blank:]]+[(]?ro[[:blank:],]"
   then echo "**ERROR**: JFFS is mounted READ-ONLY." ; return 2
   fi

   typex="$(echo "$jffsUsageStr" | awk -F ' ' '{print $2}')"
   total="$(echo "$jffsUsageStr" | awk -F ' ' '{print $3}')"
   usedx="$(echo "$jffsUsageStr" | awk -F ' ' '{print $4}')"
   freex="$(echo "$jffsUsageStr" | awk -F ' ' '{print $5}')"
   totalx="$total"
   if [ "$typex" = "ubifs" ] && [ "$((usedx + freex))" -ne "$total" ]
   then totalx="$((usedx + freex))" ; fi

   if [ "$sizeType" = "ALL" ] ; then echo "$totalx" ; return 0 ; fi

   case "$sizeUnits" in
       KB|KBP|MBP|GBP)
           case "$sizeType" in
               USED) sizeNum="$usedx"
                     percentNum="$(printf "%.1f" "$(_GetNum_ "($usedx * 100 / $totalx)")")"
                     percentStr="[${percentNum}%]"
                     ;;
               FREE) sizeNum="$freex"
                     percentNum="$(printf "%.1f" "$(_GetNum_ "($freex * 100 / $totalx)")")"
                     percentStr="[${percentNum}%]"
                     ;;
           esac
           case "$sizeUnits" in
                KB) sizeInfo="$sizeNum"
                    ;;
               KBP) sizeInfo="${sizeNum}.0KB $percentStr"
                    ;;
               MBP) sizeNum="$(_GetNum_ "($sizeNum / $oneKByte)")"
                    sizeInfo="${sizeNum}MB $percentStr"
                    ;;
               GBP) sizeNum="$(_GetNum_ "($sizeNum / $oneMByte)")"
                    sizeInfo="${sizeNum}GB $percentStr"
                    ;;
           esac
           echo "$sizeInfo"
           ;;
       HR|HRx)
           jffsUsageStr="$(df -hT /jffs | grep -E '.*[[:blank:]]+/jffs$')"
           case "$sizeType" in
               USED) usedx="$(echo "$jffsUsageStr" | awk -F ' ' '{print $4}')"
                     sizeInfo="${usedx}B"
                     ;;
               FREE) freex="$(echo "$jffsUsageStr" | awk -F ' ' '{print $5}')"
                     sizeInfo="${freex}B"
                     ;;
           esac
           if [ "$sizeUnits" = "HR" ]
           then echo "$sizeInfo" ; return 0 ; fi
           sizeUnits="$(echo "$sizeInfo" | tr -d '.0-9')"
           case "$sizeUnits" in
               KB) sizeInfo="$(_Get_JFFS_Space_ "$sizeType" KBP)" ;;
               MB) sizeInfo="$(_Get_JFFS_Space_ "$sizeType" MBP)" ;;
               GB) sizeInfo="$(_Get_JFFS_Space_ "$sizeType" GBP)" ;;
           esac
           echo "$sizeInfo"
           ;;
       *) echo 0 ;;
   esac
   return 0
}

##-------------------------------------##
## Added by Martinski W. [2025-Feb-15] ##
##-------------------------------------##
##--------------------------------------------------------##
## Minimum Reserved JFFS Available Free Space is roughly
## about 20% of total space or about 9MB to 10MB.
##--------------------------------------------------------##
_JFFS_MinReservedFreeSpace_()
{
   local jffsAllxSpace  jffsMinxSpace

   if ! jffsAllxSpace="$(_Get_JFFS_Space_ ALL KB)"
   then echo "$jffsAllxSpace" ; return 1 ; fi
   jffsAllxSpace="$(echo "$jffsAllxSpace" | awk '{printf("%s", $1 * 1024);}')"

   jffsMinxSpace="$(echo "$jffsAllxSpace" | awk '{printf("%d", $1 * 20 / 100);}')"
   if [ "$(echo "$jffsMinxSpace $ni9MByte" | awk -F ' ' '{print ($1 < $2)}')" -eq 1 ]
   then jffsMinxSpace="$ni9MByte"
   elif [ "$(echo "$jffsMinxSpace $tenMByte" | awk -F ' ' '{print ($1 > $2)}')" -eq 1 ]
   then jffsMinxSpace="$tenMByte"
   fi
   echo "$jffsMinxSpace" ; return 0
}

##-------------------------------------##
## Added by Martinski W. [2025-Feb-15] ##
##-------------------------------------##
##--------------------------------------------------------##
## Check JFFS free space *BEFORE* moving files from USB.
##--------------------------------------------------------##
_Check_JFFS_SpaceAvailable_()
{
   local requiredSpace  jffsFreeSpace  jffsMinxSpace
   if [ $# -eq 0 ] || [ -z "$1" ] || [ ! -d "$1" ] ; then return 0 ; fi

   [ "$1" = "/jffs/addons/${SCRIPT_NAME_LOWER}.d" ] && return 0

   if ! jffsFreeSpace="$(_Get_JFFS_Space_ FREE KB)" ; then return 1 ; fi
   if ! jffsMinxSpace="$(_JFFS_MinReservedFreeSpace_)" ; then return 1 ; fi
   jffsFreeSpace="$(echo "$jffsFreeSpace" | awk '{printf("%s", $1 * 1024);}')"

   requiredSpace="$(du -kc "$1" | grep -w 'total$' | awk -F ' ' '{print $1}')"
   requiredSpace="$(echo "$requiredSpace" | awk '{printf("%s", $1 * 1024);}')"
   requiredSpace="$(echo "$requiredSpace $jffsMinxSpace" | awk -F ' ' '{printf("%s", $1 + $2);}')"
   if [ "$(echo "$requiredSpace $jffsFreeSpace" | awk -F ' ' '{print ($1 < $2)}')" -eq 1 ]
   then return 0 ; fi

   ## Current JFFS Available Free Space is NOT sufficient ##
   requiredSpace="$(du -hc "$1" | grep -w 'total$' | awk -F ' ' '{print $1}')"
   errorMsg1="Not enough free space [$(_Get_JFFS_Space_ FREE HR)] available in JFFS."
   errorMsg2="Minimum storage space required: $requiredSpace"
   Print_Output true "${errorMsg1} ${errorMsg2}" "$CRIT"
   return 1
}

##-------------------------------------##
## Added by Martinski W. [2025-Jun-19] ##
##-------------------------------------##
_EscapeChars_()
{ printf "%s" "$1" | sed 's/[][\/$.*^&-]/\\&/g' ; }

##-------------------------------------##
## Added by Martinski W. [2025-Feb-15] ##
##-------------------------------------##
_WriteVarDefToJSFile_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
   then return 1; fi

   local varValue  sedValue
   if [ $# -eq 3 ] && [ "$3" = "true" ]
   then
       varValue="$2"
   else
       varValue="'${2}'"
       sedValue="$(_EscapeChars_ "$varValue")"
   fi

   local targetJSfile="$SCRIPT_STORAGE_DIR/ntpstatstext.js"
   if [ ! -s "$targetJSfile" ]
   then
       echo "var $1 = ${varValue};" > "$targetJSfile"
   elif
      ! grep -q "^var $1 =.*" "$targetJSfile"
   then
       sed -i "1 i var $1 = ${varValue};" "$targetJSfile"
   elif
      ! grep -q "^var $1 = ${sedValue};" "$targetJSfile"
   then
       sed -i "s/^var $1 =.*/var $1 = ${sedValue};/" "$targetJSfile"
   fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Feb-15] ##
##-------------------------------------##
_DelVarDefFromJSFile_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1; fi

   local targetJSfile="$SCRIPT_STORAGE_DIR/ntpstatstext.js"
   if [ -s "$targetJSfile" ] && \
      grep -q "^var $1 =.*" "$targetJSfile"
   then
       sed -i "/^var $1 =.*/d" "$targetJSfile"
   fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Feb-15] ##
##-------------------------------------##
JFFS_WarningLogTime()
{
   case "$1" in
       update)
           sed -i 's/^JFFS_MSGLOGTIME=.*$/JFFS_MSGLOGTIME='"$2"'/' "$SCRIPT_CONF"
           ;;
       check)
           JFFS_MSGLOGTIME="$(_GetConfigParam_ JFFS_MSGLOGTIME 0)"
           if ! echo "$JFFS_MSGLOGTIME" | grep -qE "^[0-9]+$"
           then JFFS_MSGLOGTIME=0
           fi
           echo "$JFFS_MSGLOGTIME"
           ;;
   esac
}

##-------------------------------------##
## Added by Martinski W. [2025-Feb-20] ##
##-------------------------------------##
_JFFS_WarnLowFreeSpace_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 0 ; fi
   local jffsWarningLogFreq  jffsWarningLogTime  storageLocStr
   local logPriNum  logTagStr  logMsgStr  currTimeSecs  currTimeDiff

   storageLocStr="$(ScriptStorageLocation check | tr 'a-z' 'A-Z')"
   if [ "$storageLocStr" = "JFFS" ]
   then
       if [ "$JFFS_LowFreeSpaceStatus" = "WARNING2" ]
       then
           logPriNum=2
           logTagStr="**ALERT**"
           jffsWarningLogFreq="$_12Hours"
       else
           logPriNum=3
           logTagStr="**WARNING**"
           jffsWarningLogFreq="$_24Hours"
       fi
   else
       if [ "$JFFS_LowFreeSpaceStatus" = "WARNING2" ]
       then
           logPriNum=3
           logTagStr="**WARNING**"
           jffsWarningLogFreq="$_24Hours"
       else
           logPriNum=4
           logTagStr="**NOTICE**"
           jffsWarningLogFreq="$_36Hours"
       fi
   fi
   jffsWarningLogTime="$(JFFS_WarningLogTime check)"

   currTimeSecs="$(date +'%s')"
   currTimeDiff="$(echo "$currTimeSecs $jffsWarningLogTime" | awk -F ' ' '{printf("%s", $1 - $2);}')"
   if [ "$currTimeDiff" -ge "$jffsWarningLogFreq" ]
   then
       JFFS_WarningLogTime update "$currTimeSecs"
       logMsgStr="${logTagStr} JFFS Available Free Space ($1) is getting LOW."
       logger -t "${SCRIPT_NAME}_[$$]" -p $logPriNum "$logMsgStr"
   fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Feb-20] ##
##-------------------------------------##
_UpdateJFFS_FreeSpaceInfo_()
{
   local jffsFreeSpaceHR  jffsFreeSpace  jffsMinxSpace
   [ ! -d "$SCRIPT_STORAGE_DIR" ] && return 1

   jffsFreeSpaceHR="$(_Get_JFFS_Space_ FREE HRx)"
   _DelVarDefFromJSFile_ "jffsAvailableSpace"
   _WriteVarDefToJSFile_ "jffsAvailableSpaceStr" "$jffsFreeSpaceHR"

   if ! jffsFreeSpace="$(_Get_JFFS_Space_ FREE KB)" ; then return 1 ; fi
   if ! jffsMinxSpace="$(_JFFS_MinReservedFreeSpace_)" ; then return 1 ; fi
   jffsFreeSpace="$(echo "$jffsFreeSpace" | awk '{printf("%s", $1 * 1024);}')"

   JFFS_LowFreeSpaceStatus="OK"
   ## Warning Level 1 if JFFS Available Free Space is LESS than Minimum Reserved ##
   if [ "$(echo "$jffsFreeSpace $jffsMinxSpace" | awk -F ' ' '{print ($1 < $2)}')" -eq 1 ]
   then
       JFFS_LowFreeSpaceStatus="WARNING1"
       ## Warning Level 2 if JFFS Available Free Space is LESS than 8.0MB ##
       if [ "$(echo "$jffsFreeSpace $ei8MByte" | awk -F ' ' '{print ($1 < $2)}')" -eq 1 ]
       then
           JFFS_LowFreeSpaceStatus="WARNING2"
       fi
       _JFFS_WarnLowFreeSpace_ "$jffsFreeSpaceHR"
   fi
   _WriteVarDefToJSFile_ "jffsAvailableSpaceLow" "$JFFS_LowFreeSpaceStatus"
}

##-------------------------------------##
## Added by Martinski W. [2025-Feb-15] ##
##-------------------------------------##
_UpdateDatabaseFileSizeInfo_()
{
   local databaseFileSize
   [ ! -d "$SCRIPT_STORAGE_DIR" ] && return 1

   _UpdateJFFS_FreeSpaceInfo_
   databaseFileSize="$(_GetFileSize_ "$NTPDSTATS_DB" HRx)"
   _WriteVarDefToJSFile_ "sqlDatabaseFileSize" "$databaseFileSize"
}

##-------------------------------------##
## Added by Martinski W. [2025-Jun-04] ##
##-------------------------------------##
_SQLCheckDBLogFileSize_()
{
   if [ "$(_GetFileSize_ "$sqlDBLogFilePath")" -gt "$sqlDBLogFileSize" ]
   then
       cp -fp "$sqlDBLogFilePath" "${sqlDBLogFilePath}.BAK"
       echo -n > "$sqlDBLogFilePath"
   fi
}

_SQLGetDBLogTimeStamp_()
{ printf "[$(date +"$sqlDBLogDateTime")]" ; }

##----------------------------------------##
## Modified by Martinski W. [2025-Jul-20] ##
##----------------------------------------##
readonly errorMsgsRegExp="Parse error|Runtime error|Error:"
readonly corruptedBinExp="Illegal instruction|SQLite header and source version mismatch"
readonly sqlErrorsRegExp="($errorMsgsRegExp|$corruptedBinExp)"
readonly sqlLockedRegExp="(Parse|Runtime) error .*: database is locked"
readonly sqlCorruptedMsg="SQLite3 binary is likely corrupted. Remove and reinstall the Entware package."
##-----------------------------------------------------------------------
_ApplyDatabaseSQLCmds_()
{
    local errorCount=0  maxErrorCount=3  callFlag
    local triesCount=0  maxTriesCount=10  sqlErrorMsg
    local tempLogFilePath="/tmp/${SCRIPT_NAME}Stats_TMP_$$.LOG"
    local debgLogFilePath="/tmp/${SCRIPT_NAME}Stats_DEBUG_$$.LOG"
    local debgLogSQLcmds=false

    if [ $# -gt 1 ] && [ -n "$2" ]
    then callFlag="$2"
    else callFlag="err"
    fi

    resultStr=""
    foundError=false ; foundLocked=false
    rm -f "$tempLogFilePath" "$debgLogFilePath"

    while [ "$errorCount" -lt "$maxErrorCount" ] && \
          [ "$((triesCount++))" -lt "$maxTriesCount" ]
    do
        if "$SQLITE3_PATH" "$NTPDSTATS_DB" < "$1" >> "$tempLogFilePath" 2>&1
        then foundError=false ; foundLocked=false ; break
        fi
        sqlErrorMsg="$(cat "$tempLogFilePath")"

        if echo "$sqlErrorMsg" | grep -qE "^$sqlErrorsRegExp"
        then
            if echo "$sqlErrorMsg" | grep -qE "^$sqlLockedRegExp"
            then
                foundLocked=true ; maxTriesCount=25
                echo -n > "$tempLogFilePath"  ##Clear for next error found##
                sleep 2 ; continue
            fi
            if echo "$sqlErrorMsg" | grep -qE "^($corruptedBinExp)"
            then  ## Corrupted SQLite3 Binary?? ##
                errorCount="$maxErrorCount"
                echo "$sqlCorruptedMsg" >> "$tempLogFilePath"
                Print_Output true "SQLite3 Fatal Error[$callFlag]: $sqlCorruptedMsg" "$CRIT"
            fi
            errorCount="$((errorCount + 1))"
            foundError=true ; foundLocked=false
            Print_Output true "SQLite3 Failure[$callFlag]: $sqlErrorMsg" "$ERR"
        fi

        if ! "$debgLogSQLcmds"
        then
           debgLogSQLcmds=true
           {
              echo "==========================================="
              echo "$(_SQLGetDBLogTimeStamp_) BEGIN [$callFlag]"
              echo "Database: $NTPDSTATS_DB"
           } > "$debgLogFilePath"
        fi
        cat "$tempLogFilePath" >> "$debgLogFilePath"
        echo -n > "$tempLogFilePath"  ##Clear for next error found##
        [ "$triesCount" -ge "$maxTriesCount" ] && break
        [ "$errorCount" -ge "$maxErrorCount" ] && break
        sleep 1
    done

    if "$debgLogSQLcmds"
    then
       {
          echo "--------------------------------"
          cat "$1"
          echo "--------------------------------"
          echo "$(_SQLGetDBLogTimeStamp_) END [$callFlag]"
       } >> "$debgLogFilePath"
       cat "$debgLogFilePath" >> "$sqlDBLogFilePath"
    fi

    rm -f "$tempLogFilePath" "$debgLogFilePath"
    if "$foundError"
    then resultStr="reported error(s)."
    elif "$foundLocked"
    then resultStr="found database locked."
    else resultStr="completed successfully."
    fi
    if "$foundError" || "$foundLocked"
    then
        Print_Output true "SQLite process[$callFlag] ${resultStr}" "$ERR"
    fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Jan-29] ##
##-------------------------------------##
_Optimize_Database_()
{
   renice 15 $$
   local foundError  foundLocked  resultStr

   Print_Output true "Running database analysis and optimization..." "$PASS"
   {
      echo "PRAGMA temp_store=1;"
      echo "PRAGMA journal_mode=TRUNCATE;"
      echo "PRAGMA analysis_limit=0;"
      echo "PRAGMA cache_size=-20000;"
      echo "ANALYZE ntpstats;"
      echo "VACUUM;"
   } > /tmp/ntpMerlin-trim.sql
   _ApplyDatabaseSQLCmds_ /tmp/ntpMerlin-trim.sql opt1

   rm -f /tmp/ntpMerlin-trim.sql
   if "$foundError" || "$foundLocked"
   then Print_Output true "Database analysis and optimization ${resultStr}" "$ERR"
   else Print_Output true "Database analysis and optimization ${resultStr}" "$PASS"
   fi
   renice 0 $$
}

##-------------------------------------##
## Added by Martinski W. [2025-Jan-29] ##
##-------------------------------------##
_Trim_Database_()
{
   renice 15 $$
   TZ="$(cat /etc/TZ)"
   export TZ
   timeNow="$(date +'%s')"

   local foundError  foundLocked  resultStr

   Print_Output true "Trimming records from database..." "$PASS"
   {
      echo "PRAGMA temp_store=1;"
      echo "PRAGMA journal_mode=TRUNCATE;"
      echo "PRAGMA cache_size=-20000;"
      echo "DELETE FROM [ntpstats] WHERE [Timestamp] < strftime('%s',datetime($timeNow,'unixepoch','-$(DaysToKeep check) day'));"
   } > /tmp/ntpMerlin-trim.sql
   _ApplyDatabaseSQLCmds_ /tmp/ntpMerlin-trim.sql trm1

   rm -f /tmp/ntpMerlin-trim.sql
   if "$foundError" || "$foundLocked"
   then Print_Output true "Database record trimming ${resultStr}" "$ERR"
   else Print_Output true "Database record trimming ${resultStr}" "$PASS"
   fi
   renice 0 $$
}

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-15] ##
##----------------------------------------##
Get_TimeServer_Stats()
{
	if [ ! -f /opt/bin/xargs ] && [ -x /opt/bin/opkg ]
	then
		Print_Output true "Installing findutils from Entware" "$PASS"
		opkg update
		opkg install findutils
	fi
	if [ -n "$PPID" ]; then
		ps | grep -v grep | grep -v $$ | grep -v "$PPID" | grep -i "$SCRIPT_NAME" | grep generate | awk '{print $1}' | xargs kill -9 >/dev/null 2>&1
	else
		ps | grep -v grep | grep -v $$ | grep -i "$SCRIPT_NAME" | grep generate | awk '{print $1}' | xargs kill -9 >/dev/null 2>&1
	fi
	Create_Dirs
	Conf_Exists
	Auto_Startup create 2>/dev/null
	Auto_Cron create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	NTP_Firmware_Check
	ScriptStorageLocation load
	Create_Symlinks

	echo 'var ntpstatus = "InProgress";' > /tmp/detect_ntpmerlin.js

	killall -q ntp 2>/dev/null

	TIMESERVER="$(TimeServer check)"
	if [ "$TIMESERVER" = "ntpd" ]
	then
		tmpfile=/tmp/ntp-stats.$$
		ntpq -4 -c rv | awk 'BEGIN{ RS=","}{ print }' > "$tmpfile"
		
		[ -n "$(grep offset "$tmpfile" | awk 'BEGIN{FS="="}{print $2}')" ] && NOFFSET=$(grep offset "$tmpfile" | awk 'BEGIN{FS="="}{print $2}') || NOFFSET=0
		[ -n "$(grep frequency "$tmpfile" | awk 'BEGIN{FS="="}{print $2}')" ] && NFREQ=$(grep frequency "$tmpfile" | awk 'BEGIN{FS="="}{print $2}') || NFREQ=0
		[ -n "$(grep sys_jitter "$tmpfile" | awk 'BEGIN{FS="="}{print $2}')" ] && NSJIT=$(grep sys_jitter "$tmpfile" | awk 'BEGIN{FS="="}{print $2}') || NSJIT=0
		[ -n "$(grep clk_jitter "$tmpfile" | awk 'BEGIN{FS="="}{print $2}')" ] && NCJIT=$(grep clk_jitter "$tmpfile" | awk 'BEGIN{FS="="}{print $2}') || NCJIT=0
		[ -n "$(grep clk_wander "$tmpfile" | awk 'BEGIN{FS="="}{print $2}')" ] && NWANDER=$(grep clk_wander "$tmpfile" | awk 'BEGIN{FS="="}{print $2}') || NWANDER=0
		[ -n "$(grep rootdisp "$tmpfile" | awk 'BEGIN{FS="="}{print $2}')" ] &&  NDISPER=$(grep rootdisp "$tmpfile" | awk 'BEGIN{FS="="}{print $2}') || NDISPER=0
		rm -f "$tmpfile"
	elif [ "$TIMESERVER" = "chronyd" ]
	then
		tmpfile=/tmp/chrony-stats.$$
		chronyc tracking > "$tmpfile"
		
		[ -n "$(grep "Last offset" "$tmpfile" | awk '{print $4}')" ] && NOFFSET=$(grep Last "$tmpfile" | awk '{print $4}') || NOFFSET=0
		[ -n "$(grep Frequency "$tmpfile" | awk '{print $3}')" ] && NFREQ=$(grep Frequency "$tmpfile" | awk '{print $3}') || NFREQ=0
		[ -n "$(grep System "$tmpfile" | awk '{print $4}')" ] && NSJIT=$(grep System "$tmpfile" | awk '{print $4}') || NSJIT=0
		[ -n "$(grep Skew "$tmpfile" | awk '{print $3}')" ] && NWANDER=$(grep Skew "$tmpfile" | awk '{print $3}') || NWANDER=0
		[ -n "$(grep dispersion "$tmpfile" | awk '{print $4}')" ] && NDISPER=$(grep dispersion "$tmpfile" | awk '{print $4}') || NDISPER=0
		
		NOFFSET="$(echo "$NOFFSET" | awk '{printf ($1*1000)}')"
		NSJIT="$(echo "$NSJIT" | awk '{printf ($1*1000)}')"
		NCJIT=0
		NDISPER="$(echo "$NDISPER" | awk '{printf ($1*1000)}')"
		rm -f "$tmpfile"
	fi

	TZ="$(cat /etc/TZ)"
	export TZ
	timenow="$(date +"%s")"
	timenowfriendly="$(date +"%c")"

	Process_Upgrade

	{
	   echo "PRAGMA temp_store=1;"
	   echo "PRAGMA journal_mode=TRUNCATE;"
	   echo "CREATE TABLE IF NOT EXISTS [ntpstats] ([StatID] INTEGER PRIMARY KEY NOT NULL,[Timestamp] NUMERIC NOT NULL,[Offset] REAL NOT NULL,[Frequency] REAL NOT NULL,[Sys_Jitter] REAL NOT NULL,[Clk_Jitter] REAL NOT NULL,[Clk_Wander] REAL NOT NULL,[Rootdisp] REAL NOT NULL);"
	   echo "INSERT INTO ntpstats ([Timestamp],[Offset],[Frequency],[Sys_Jitter],[Clk_Jitter],[Clk_Wander],[Rootdisp]) values($timenow,$NOFFSET,$NFREQ,$NSJIT,$NCJIT,$NWANDER,$NDISPER);"
	} > /tmp/ntpMerlin-stats.sql
	_ApplyDatabaseSQLCmds_ /tmp/ntpMerlin-stats.sql tme1
	rm -f /tmp/ntpMerlin-stats.sql

	echo 'var ntpstatus = "GenerateCSV";' > /tmp/detect_ntpmerlin.js
	Generate_CSVs

	_UpdateDatabaseFileSizeInfo_

	echo "Stats last updated: $timenowfriendly" > /tmp/ntpstatstitle.txt
	WriteStats_ToJS /tmp/ntpstatstitle.txt "$SCRIPT_STORAGE_DIR/ntpstatstext.js" SetNTPDStatsTitle statstitle
	rm -f /tmp/ntpstatstitle.txt

	echo 'var ntpstatus = "Done";' > /tmp/detect_ntpmerlin.js
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-20] ##
##----------------------------------------##
Generate_CSVs()
{
	local foundError  foundLocked  resultStr  sqlProcSuccess

	Process_Upgrade

	renice 15 $$

	OUTPUTTIMEMODE="$(OutputTimeMode check)"
	TZ="$(cat /etc/TZ)"
	export TZ
	timenow="$(date +"%s")"
	timenowfriendly="$(date +"%c")"

	metricList="Offset Frequency"
	for metric in $metricList
	do
		FILENAME="$metric"
		if [ "$metric" = "Frequency" ]; then
			FILENAME="Drift"
		fi
		{
			echo ".mode csv"
			echo ".headers on"
			echo ".output $CSV_OUTPUT_DIR/${FILENAME}_raw_daily.htm"
			echo "PRAGMA temp_store=1;"
			echo "SELECT '$metric' Metric,[Timestamp] Time,printf('%f', $metric) Value FROM ntpstats WHERE ([Timestamp] >= strftime('%s',datetime($timenow,'unixepoch','-1 day'))) ORDER BY [Timestamp] DESC;"
		} > /tmp/ntpMerlin-stats.sql
		_ApplyDatabaseSQLCmds_ /tmp/ntpMerlin-stats.sql gnr1

		{
			echo ".mode csv"
			echo ".headers on"
			echo ".output $CSV_OUTPUT_DIR/${FILENAME}_raw_weekly.htm"
			echo "PRAGMA temp_store=1;"
			echo "SELECT '$metric' Metric,[Timestamp] Time,printf('%f', $metric) Value FROM ntpstats WHERE ([Timestamp] >= strftime('%s',datetime($timenow,'unixepoch','-7 day'))) ORDER BY [Timestamp] DESC;"
		} > /tmp/ntpMerlin-stats.sql
		_ApplyDatabaseSQLCmds_ /tmp/ntpMerlin-stats.sql gnr2

		{
			echo ".mode csv"
			echo ".headers on"
			echo ".output $CSV_OUTPUT_DIR/${FILENAME}_raw_monthly.htm"
			echo "PRAGMA temp_store=1;"
			echo "SELECT '$metric' Metric,[Timestamp] Time,printf('%f', $metric) Value FROM ntpstats WHERE ([Timestamp] >= strftime('%s',datetime($timenow,'unixepoch','-30 day'))) ORDER BY [Timestamp] DESC;"
		} > /tmp/ntpMerlin-stats.sql
		_ApplyDatabaseSQLCmds_ /tmp/ntpMerlin-stats.sql gnr3
		
		WriteSql_ToFile "$metric" ntpstats 1 1 "$CSV_OUTPUT_DIR/${FILENAME}_hour" daily /tmp/ntpMerlin-stats.sql "$timenow"
		_ApplyDatabaseSQLCmds_ /tmp/ntpMerlin-stats.sql gnr4
		
		WriteSql_ToFile "$metric" ntpstats 1 7 "$CSV_OUTPUT_DIR/${FILENAME}_hour" weekly /tmp/ntpMerlin-stats.sql "$timenow"
		_ApplyDatabaseSQLCmds_ /tmp/ntpMerlin-stats.sql gnr5
		
		WriteSql_ToFile "$metric" ntpstats 1 30 "$CSV_OUTPUT_DIR/${FILENAME}_hour" monthly /tmp/ntpMerlin-stats.sql "$timenow"
		_ApplyDatabaseSQLCmds_ /tmp/ntpMerlin-stats.sql gnr6
		
		WriteSql_ToFile "$metric" ntpstats 24 1 "$CSV_OUTPUT_DIR/${FILENAME}_day" daily /tmp/ntpMerlin-stats.sql "$timenow"
		_ApplyDatabaseSQLCmds_ /tmp/ntpMerlin-stats.sql gnr7
		
		WriteSql_ToFile "$metric" ntpstats 24 7 "$CSV_OUTPUT_DIR/${FILENAME}_day" weekly /tmp/ntpMerlin-stats.sql "$timenow"
		_ApplyDatabaseSQLCmds_ /tmp/ntpMerlin-stats.sql gnr8
		
		WriteSql_ToFile "$metric" ntpstats 24 30 "$CSV_OUTPUT_DIR/${FILENAME}_day" monthly /tmp/ntpMerlin-stats.sql "$timenow"
		_ApplyDatabaseSQLCmds_ /tmp/ntpMerlin-stats.sql gnr9
		
		rm -f "$CSV_OUTPUT_DIR/${FILENAME}daily.htm"
		rm -f "$CSV_OUTPUT_DIR/${FILENAME}weekly.htm"
		rm -f "$CSV_OUTPUT_DIR/${FILENAME}monthly.htm"
	done

	rm -f /tmp/ntpMerlin-stats.sql
	Generate_LastXResults

	sqlProcSuccess=true
	{
		echo ".mode csv"
		echo ".headers on"
		echo ".output $CSV_OUTPUT_DIR/CompleteResults.htm"
		echo "PRAGMA temp_store=1;"
		echo "SELECT [Timestamp],[Offset],[Frequency],[Sys_Jitter],[Clk_Jitter],[Clk_Wander],[Rootdisp] FROM ntpstats WHERE ([Timestamp] >= strftime('%s',datetime($timenow,'unixepoch','-$(DaysToKeep check) day'))) ORDER BY [Timestamp] DESC;"
	} > /tmp/ntpMerlin-complete.sql
	_ApplyDatabaseSQLCmds_ /tmp/ntpMerlin-complete.sql gnr10
	rm -f /tmp/ntpMerlin-complete.sql

	if "$foundError" || "$foundLocked" || \
	   [ ! -f "$CSV_OUTPUT_DIR/CompleteResults.htm" ]
	then sqlProcSuccess=false ; fi

	dos2unix "$CSV_OUTPUT_DIR/"*.htm

	tmpOutputDir="/tmp/${SCRIPT_NAME_LOWER}results"
	mkdir -p "$tmpOutputDir"

	[ -f "$CSV_OUTPUT_DIR/CompleteResults.htm" ] && \
	mv -f "$CSV_OUTPUT_DIR/CompleteResults.htm" "$tmpOutputDir/CompleteResults.htm"

	if [ "$OUTPUTTIMEMODE" = "unix" ]
	then
		find "$tmpOutputDir/" -name '*.htm' -exec sh -c 'i="$1"; mv -- "$i" "${i%.htm}.csv"' _ {} \;
	elif [ "$OUTPUTTIMEMODE" = "non-unix" ]
	then
		for i in "$tmpOutputDir/"*".htm"; do
			awk -F"," 'NR==1 {OFS=","; print} NR>1 {OFS=","; $1=strftime("%Y-%m-%d %H:%M:%S", $1); print }' "$i" > "$i.out"
		done
		
		find "$tmpOutputDir/" -name '*.htm.out' -exec sh -c 'i="$1"; mv -- "$i" "${i%.htm.out}.csv"' _ {} \;
		rm -f "$tmpOutputDir/"*.htm
	fi

	[ -f "$tmpOutputDir/CompleteResults.csv" ] && \
	mv -f "$tmpOutputDir/CompleteResults.csv" "$CSV_OUTPUT_DIR/CompleteResults.htm"

	rm -f "$CSV_OUTPUT_DIR/ntpmerlindata.zip"
	rm -rf "$tmpOutputDir"

	renice 0 $$
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-20] ##
##----------------------------------------##
Generate_LastXResults()
{
	local foundError  foundLocked  resultStr  sqlProcSuccess

	rm -f "$SCRIPT_STORAGE_DIR/lastx.htm"
	rm -f /tmp/ntpMerlin-lastx.csv

	sqlProcSuccess=true
	{
	   echo ".mode csv"
	   echo ".output /tmp/ntpMerlin-lastx.csv"
	   echo "PRAGMA temp_store=1;"
	   echo "SELECT [Timestamp],[Offset],[Frequency] FROM ntpstats ORDER BY [Timestamp] DESC LIMIT $(LastXResults check);"
	} > /tmp/ntpMerlin-lastx.sql
	_ApplyDatabaseSQLCmds_ /tmp/ntpMerlin-lastx.sql glx1
	rm -f /tmp/ntpMerlin-lastx.sql

	if "$foundError" || "$foundLocked" || [ ! -f /tmp/ntpMerlin-lastx.csv ]
	then
		sqlProcSuccess=false
		Print_Output true "**ERROR**: Generate Last X Results Failed" "$ERR"
	fi

	if "$sqlProcSuccess"
	then
		sed -i 's/"//g' /tmp/ntpMerlin-lastx.csv
		mv -f /tmp/ntpMerlin-lastx.csv "$SCRIPT_STORAGE_DIR/lastx.csv"
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-15] ##
##----------------------------------------##
Reset_DB()
{
	SIZEAVAIL="$(df -kP "$SCRIPT_STORAGE_DIR" | awk -F ' ' '{print $4}' | tail -n 1)"
	SIZEDB="$(ls -l "$NTPDSTATS_DB" | awk -F ' ' '{print $5}')"
	SIZEAVAIL="$(echo "$SIZEAVAIL" | awk '{printf("%s", $1 * 1024);}')"

	if [ "$(echo "$SIZEAVAIL $SIZEDB" | awk -F ' ' '{print ($1 < $2)}')" -eq 1 ]
	then
		Print_Output true "Database size exceeds available space. $(ls -lh "$NTPDSTATS_DB" | awk '{print $5}')B is required to create backup." "$ERR"
		return 1
	else
		Print_Output true "Sufficient free space to back up database, proceeding..." "$PASS"
		if ! cp -a "$NTPDSTATS_DB" "${NTPDSTATS_DB}.bak"; then
			Print_Output true "Database backup failed, please check storage device" "$WARN"
		fi

		Print_Output false "Please wait..." "$PASS"
		{
		   echo "PRAGMA temp_store=1;"
		   echo "DELETE FROM [ntpstats];"
		} > /tmp/ntpMerlin-reset.sql
		_ApplyDatabaseSQLCmds_ /tmp/ntpMerlin-reset.sql rst1
		rm -f /tmp/ntpMerlin-reset.sql

		## Clear/Reset all CSV files ##
		Generate_CSVs

		## Show "reset" messages on webGUI ##
		timeDateNow="$(/bin/date +"%c")"
		extraJScode='databaseResetDone += 1;'
		echo "Resetting stats: $timeDateNow" > /tmp/ntpstatstitle.txt
		WriteStats_ToJS /tmp/ntpstatstitle.txt "$SCRIPT_STORAGE_DIR/ntpstatstext.js" SetNTPDStatsTitle statstitle "$extraJScode"
		rm -f /tmp/ntpstatstitle.txt
		sleep 2
		Print_Output true "Database reset complete" "$WARN"
		{
		   sleep 4
		   _UpdateDatabaseFileSizeInfo_
		   timeDateNow="$(/bin/date +"%c")"
		   extraJScode='databaseResetDone = 0;'
		   echo "Stats were reset: $timeDateNow" > /tmp/ntpstatstitle.txt
		   WriteStats_ToJS /tmp/ntpstatstitle.txt "$SCRIPT_STORAGE_DIR/ntpstatstext.js" SetNTPDStatsTitle statstitle "$extraJScode"
		   rm -f /tmp/ntpstatstitle.txt
		} &
	fi
}

Shortcut_Script()
{
	case $1 in
		create)
			if [ -d /opt/bin ] && [ ! -f "/opt/bin/$SCRIPT_NAME_LOWER" ] && \
			   [ -f "/jffs/scripts/$SCRIPT_NAME_LOWER" ]
			then
				ln -s "/jffs/scripts/$SCRIPT_NAME_LOWER" /opt/bin
				chmod 0755 "/opt/bin/$SCRIPT_NAME_LOWER"
			fi
		;;
		delete)
			if [ -f "/opt/bin/$SCRIPT_NAME_LOWER" ]; then
				rm -f "/opt/bin/$SCRIPT_NAME_LOWER"
			fi
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-15] ##
##----------------------------------------##
Process_Upgrade()
{
	local foundError  foundLocked  resultStr  doUpdateDB=false

	rm -f "$SCRIPT_STORAGE_DIR/.tableupgraded"
	if [ ! -f "$SCRIPT_STORAGE_DIR/.chronyugraded" ]
	then
		if [ "$(TimeServer check)" = "chronyd" ]
		then
			Print_Output true "Checking if chrony-nts is available for your router..." "$PASS"
			opkg update >/dev/null 2>&1
			if [ -n "$(opkg info chrony-nts)" ]
			then
				Print_Output true "chrony-nts is available, replacing chrony with chrony-nts..." "$PASS"
				/opt/etc/init.d/S77chronyd stop >/dev/null 2>&1
				rm -f /opt/etc/init.d/S77chronyd /opt/etc/init.d/S77ntpd
				opkg remove chrony >/dev/null 2>&1
				opkg install chrony-nts >/dev/null 2>&1
				Update_File chrony.conf >/dev/null 2>&1
				Update_File S77chronyd >/dev/null 2>&1
			else
				Print_Output true "chrony-nts not found in Entware for your router" "$WARN"
			fi
			touch "$SCRIPT_STORAGE_DIR/.chronyugraded"
		fi
	fi
	if [ ! -f "$SCRIPT_STORAGE_DIR/.indexcreated" ]
	then
		renice 15 $$
		Print_Output true "Creating database table indexes..." "$PASS"
		{
		   echo "PRAGMA temp_store=1;"
		   echo "PRAGMA cache_size=-20000;"
		   echo "CREATE INDEX IF NOT EXISTS idx_time_offset ON ntpstats (Timestamp,Offset);" 
		} > /tmp/ntpMerlin-upgrade.sql
		_ApplyDatabaseSQLCmds_ /tmp/ntpMerlin-upgrade.sql prc1

		{
		   echo "PRAGMA temp_store=1;"
		   echo "PRAGMA cache_size=-20000;"
		   echo "CREATE INDEX IF NOT EXISTS idx_time_frequency ON ntpstats (Timestamp,Frequency);" 
		} > /tmp/ntpMerlin-upgrade.sql
		_ApplyDatabaseSQLCmds_ /tmp/ntpMerlin-upgrade.sql prc2

		rm -f /tmp/ntpMerlin-upgrade.sql
		touch "$SCRIPT_STORAGE_DIR/.indexcreated"
		Print_Output true "Database ready, continuing..." "$PASS"
		renice 0 $$
		doUpdateDB=true
	fi
	if [ ! -f "$SCRIPT_STORAGE_DIR/lastx.csv" ]
	then
		Generate_LastXResults
		doUpdateDB=true
	fi
	if [ ! -f "$SCRIPT_STORAGE_DIR/ntpstatstext.js" ]
	then
		doUpdateDB=true
		echo "Stats last updated: Not yet updated" > /tmp/ntpstatstitle.txt
		WriteStats_ToJS /tmp/ntpstatstitle.txt "$SCRIPT_STORAGE_DIR/ntpstatstext.js" SetNTPDStatsTitle statstitle 
	fi
	"$doUpdateDB" && _UpdateDatabaseFileSizeInfo_
}

PressEnter()
{
	while true
	do
		printf "Press <Enter> key to continue..."
		read -rs key
		case "$key" in
			*) break ;;
		esac
	done
	return 0
}

##-------------------------------------##
## Added by Martinski W. [2025-Oct-25] ##
##-------------------------------------##
_CenterTextStr_()
{
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ] || \
       ! echo "$2" | grep -qE "^[1-9][0-9]+$"
    then echo ; return 1
    fi
    local stringLen="${#1}"
    local space1Len="$((($2 - stringLen)/2))"
    local space2Len="$space1Len"
    local totalLen="$((space1Len + stringLen + space2Len))"

    if [ "$totalLen" -lt "$2" ]
    then space2Len="$((space2Len + 1))"
    elif [ "$totalLen" -gt "$2" ]
    then space1Len="$((space1Len - 1))"
    fi
    if [ "$space1Len" -gt 0 ] && [ "$space2Len" -gt 0 ]
    then printf "%*s%s%*s" "$space1Len" '' "$1" "$space2Len" ''
    else printf "%s" "$1"
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-15] ##
##----------------------------------------##
ScriptHeader()
{
	local spaceLen=56  colorCT  showFullInfo=false

	if [ $# -gt 0 ] && [ "$1" = "true" ]
	then showFullInfo=true
	fi
	[ "$SCRIPT_BRANCH" = "master" ] && colorCT="$GRNct" || colorCT="$MGNTct"

	if "$showFullInfo"
	then
		DST_ENABLED="$(nvram get time_zone_dst)"
		if ! Validate_Number "$DST_ENABLED"
		then DST_ENABLED=0
		fi
		if [ "$DST_ENABLED" -ne 0 ]
		then DST_ENABLED="Active"
		else DST_ENABLED="Inactive"
		fi

		DST_SETTING="$(nvram get time_zone_dstoff)"
		DST_SETTING="$(echo "$DST_SETTING" | sed 's/M//g')"
		DST_START="$(echo "$DST_SETTING" | cut -f1 -d",")"
		DST_START="Month $(echo "$DST_START" | cut -f1 -d".") Week $(echo "$DST_START" | cut -f2 -d".") Weekday $(echo "$DST_START" | cut -f3 -d"." | cut -f1 -d"/") Hour $(echo "$DST_START" | cut -f3 -d"." | cut -f2 -d"/")"
		DST_END="$(echo "$DST_SETTING" | cut -f2 -d",")"
		DST_END="Month $(echo "$DST_END" | cut -f1 -d".") Week $(echo "$DST_END" | cut -f2 -d".") Weekday $(echo "$DST_END" | cut -f3 -d"." | cut -f1 -d"/") Hour $(echo "$DST_END" | cut -f3 -d"." | cut -f2 -d"/")"
	fi

	clear ; echo
	printf "${BOLD}##############################################################${CLRct}\n"
	printf "${BOLD}##           _           __  __              _  _           ##${CLRct}\n"
	printf "${BOLD}##          | |         |  \/  |            | |(_)          ##${CLRct}\n"
	printf "${BOLD}##    _ __  | |_  _ __  | \  / |  ___  _ __ | | _  _ __     ##${CLRct}\n"
	printf "${BOLD}##   | '_ \ | __|| '_ \ | |\/| | / _ \| '__|| || || '_ \    ##${CLRct}\n"
	printf "${BOLD}##   | | | || |_ | |_) || |  | ||  __/| |   | || || | | |   ##${CLRct}\n"
	printf "${BOLD}##   |_| |_| \__|| .__/ |_|  |_| \___||_|   |_||_||_| |_|   ##${CLRct}\n"
	printf "${BOLD}##               | |                                        ##${CLRct}\n"
	printf "${BOLD}##               |_|                                        ##${CLRct}\n"
	printf "${BOLD}##                                                          ##${CLRct}\n"
	printf "${BOLD}## ${GRNct}%s${CLRct}${BOLD} ##${CLRct}\n" "$(_CenterTextStr_ "$versionMod_TAG" "$spaceLen")"
	printf "${BOLD}## ${colorCT}%s${CLRct}${BOLD} ##${CLRct}\n" "$(_CenterTextStr_ "$branchxStr_TAG" "$spaceLen")"
	printf "${BOLD}##                                                          ##${CLRct}\n"
	printf "${BOLD}##           https://github.com/AMTM-OSR/ntpMerlin          ##${CLRct}\n"
	printf "${BOLD}##     Forked from https://github.com/jackyaz/ntpMerlin     ##${CLRct}\n"
	printf "${BOLD}##                                                          ##${CLRct}\n"

	if "$showFullInfo"
	then
	printf "${BOLD}##                 DST is currently %-8s                ##${CLRct}\n" "$DST_ENABLED"
	printf "${BOLD}##                                                          ##${CLRct}\n"
	printf "${BOLD}##      DST starts on %-33s     ##${CLRct}\n" "$DST_START"
	printf "${BOLD}##      DST ends on %-33s       ##${CLRct}\n" "$DST_END"
	printf "${BOLD}##                                                          ##${CLRct}\n"
	fi
	printf "${BOLD}##############################################################${CLRct}\n\n"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-15] ##
##----------------------------------------##
_HandleInvalidMenuOption_()
{
	[ -n "$menuOption" ] && \
	printf "\n${REDct}INVALID input [$menuOption]${CLRct}"
	printf "\nPlease choose a valid option.\n\n"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-15] ##
##----------------------------------------##
_Menu_TimeServerOptions_()
{
	local menuOption  exitMenu=false  TIMESERVER_NAME  configPath

	TIMESERVER_NAME="$(TimeServer check)"
	configPath="UNKNOWN"
	if [ "$TIMESERVER_NAME" = "ntpd" ]
	then configPath="$SCRIPT_STORAGE_DIR/ntp.conf"
	elif [ "$TIMESERVER_NAME" = "chronyd" ]
	then configPath="$SCRIPT_STORAGE_DIR/chrony.conf"
	fi

	ScriptHeader
	printf " ${BOLDUNDERLN}${GRNct}Time Server Options${CLRct}\n\n"

	printf "   ${GRNct}1${CLRct}. Edit ${SETTING}%s${CLRct} time server configuration file\n\n" "$(TimeServer check)"
	printf "  ${GRNct}ts${CLRct}. Switch time server between ${SETTING}ntpd${CLRct} and ${SETTING}chronyd${CLRct}\n"
	printf "      Currently: ${SETTING}%s${CLRct}\n" "$(TimeServer check)"
	printf "      Config location: ${SETTING}%s${CLRct}\n\n" "$configPath"
	printf "  ${GRNct}rs${CLRct}. Restart ${SETTING}%s${CLRct}\n\n" "$(TimeServer check)"
	printf "   ${GRNct}e${CLRct}. Return to Main Menu\n"
	printf "\n${menuSepStr}\n\n"

	while true
	do
		printf "Choose an option:  "
		read -r menuOption
		case "$menuOption" in
			1)
				printf "\n"
				if Check_Lock menu
				then
					Menu_Edit && PressEnter
				fi
				break
			;;
			ts)
				printf "\n"
				if Check_Lock menu
				then
					if [ "$(TimeServer check)" = "ntpd" ]
					then
						TimeServer chronyd
					elif [ "$(TimeServer check)" = "chronyd" ]
					then
						TimeServer ntpd
					fi
					Clear_Lock
				fi
				PressEnter
				break
			;;
			rs)
				printf "\n"
				TIMESERVER_NAME="$(TimeServer check)"
				Print_Output true "Restarting $TIMESERVER_NAME..." "$PASS"
				TimeServer_ServiceCheck
				"/opt/etc/init.d/S77$TIMESERVER_NAME" restart >/dev/null 2>&1
				PressEnter
				break
			;;
			e) exitMenu=true
			   break
			;;
			*)
				_HandleInvalidMenuOption_
				PressEnter
				break
			;;
		esac
	done

	"$exitMenu" && return 0
	_Menu_TimeServerOptions_
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-15] ##
##----------------------------------------##
_Menu_DatabaseOptions_()
{
	local menuOption  exitMenu=false  storageLocStr
	local jffsFreeSpace  jffsFreeSpaceStr  jffsSpaceMsgTag

	storageLocStr="$(ScriptStorageLocation check | tr 'a-z' 'A-Z')"

	_UpdateJFFS_FreeSpaceInfo_
	jffsFreeSpace="$(_Get_JFFS_Space_ FREE HRx | sed 's/%/%%/')"
	if ! echo "$JFFS_LowFreeSpaceStatus" | grep -E "^WARNING[0-9]$"
	then
		jffsFreeSpaceStr="${SETTING}$jffsFreeSpace"
	else
		if [ "$storageLocStr" = "JFFS" ]
		then jffsSpaceMsgTag="${CritBREDct} <<< WARNING! "
		else jffsSpaceMsgTag="${WarnBMGNct} <<< NOTICE! "
		fi
		jffsFreeSpaceStr="${WarnBYLWct} $jffsFreeSpace ${CLRct}  ${jffsSpaceMsgTag}${CLRct}"
	fi

	ScriptHeader
	printf " ${BOLDUNDERLN}${GRNct}Database Options${CLRct}\n\n"

	printf "   ${GRNct}1${CLRct}. Toggle time output mode\n"
	printf "      Currently: ${SETTING}%s${CLRct} time values will be used for CSV exports\n\n" "$(OutputTimeMode check)"
	printf "   ${GRNct}2${CLRct}. Set number of time server database stats to show in WebUI\n"
	printf "      Currently: ${SETTING}%s results will be shown${CLRct}\n\n" "$(LastXResults check)"
	printf "   ${GRNct}3${CLRct}. Set maximum number of days data to keep in database\n"
	printf "      Currently: ${SETTING}%s days data will be kept${CLRct}\n\n" "$(DaysToKeep check)"
	printf "   ${GRNct}s${CLRct}. Toggle storage location for database stats and config\n"
	printf "      Current location: ${SETTING}%s${CLRct}\n" "$storageLocStr"
	printf "      JFFS Available: ${jffsFreeSpaceStr}${CLRct}\n\n"
	printf "  ${GRNct}rs${CLRct}. Reset %s database / delete all data\n\n" "$SCRIPT_NAME"
	printf "   ${GRNct}e${CLRct}. Return to Main Menu\n"
	printf "\n${menuSepStr}\n\n"

	while true
	do
		printf "Choose an option:  "
		read -r menuOption
		case "$menuOption" in
			1)
				printf "\n"
				if [ "$(OutputTimeMode check)" = "unix" ]
				then
					OutputTimeMode non-unix
				elif [ "$(OutputTimeMode check)" = "non-unix" ]
				then
					OutputTimeMode unix
				fi
				break
			;;
			2)
				printf "\n"
				LastXResults update && PressEnter
				break
			;;
			3)
				printf "\n"
				DaysToKeep update && PressEnter
				break
			;;
			s)
				printf "\n"
				if Check_Lock menu
				then
					if [ "$(ScriptStorageLocation check)" = "jffs" ]
					then
					    ScriptStorageLocation usb
					elif [ "$(ScriptStorageLocation check)" = "usb" ]
					then
					    if ! _Check_JFFS_SpaceAvailable_ "$SCRIPT_STORAGE_DIR"
					    then
					        Clear_Lock
					        PressEnter
					        break
					    fi
					    ScriptStorageLocation jffs
					fi
					Create_Symlinks
					Clear_Lock
				fi
				break
			;;
			rs)
				printf "\n"
				if Check_Lock menu
				then
					Menu_ResetDB
					Clear_Lock
				fi
				PressEnter
				break
			;;
			e) exitMenu=true
			   break
			;;
			*)
				_HandleInvalidMenuOption_
				PressEnter
				break
			;;
		esac
	done

	"$exitMenu" && return 0
	_Menu_DatabaseOptions_
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-15] ##
##----------------------------------------##
MainMenu()
{
	local menuOption  ntpRedirectStatus

	if Auto_NAT check
	then ntpRedirectStatus="${PassBGRNct} ENABLED ${CLRct}"
	else ntpRedirectStatus="${CritIREDct} DISABLED ${CLRct}"
	fi
	_UpdateJFFS_FreeSpaceInfo_

	printf " WebUI for %s is available at:\n" "$SCRIPT_NAME"
	printf " ${SETTING}%s${CLRct}\n\n" "$(Get_WebUI_URL)"

	printf "   ${GRNct}1${CLRct}. Update time server stats now\n"
	printf "      Database size: ${SETTING}%s${CLRct}\n\n" "$(_GetFileSize_ "$NTPDSTATS_DB" HRx)"
	printf "   ${GRNct}2${CLRct}. Toggle redirect of all NTP traffic to %s\n" "$SCRIPT_NAME"
	printf "      Currently: ${ntpRedirectStatus}${CLRct}\n\n"
	printf "   ${GRNct}3${CLRct}. Configure time server options\n\n"
	printf "   ${GRNct}4${CLRct}. Configure database options\n\n"
	printf "   ${GRNct}u${CLRct}. Check for updates\n"
	printf "  ${GRNct}uf${CLRct}. Update %s with latest version (force update)\n\n" "$SCRIPT_NAME"
	printf "   ${GRNct}e${CLRct}. Exit %s\n\n" "$SCRIPT_NAME"
	printf "   ${GRNct}z${CLRct}. Uninstall %s\n" "$SCRIPT_NAME"
	printf "\n${menuSepStr}\n\n"

	while true
	do
		printf "Choose an option:  "
		read -r menuOption
		case "$menuOption" in
			1)
				printf "\n"
				TimeServer_ServiceCheck
				if Check_Lock menu
				then
					Get_TimeServer_Stats
					Clear_Lock
				fi
				PressEnter
				break
			;;
			2)
				printf "\n"
				if Auto_NAT check
				then
					Auto_NAT delete
					NTP_Redirect delete
					printf "${BOLD}NTP Redirect has been ${REDct}DISABLED${CLRct}\n\n"
				else
					Auto_NAT create
					NTP_Redirect create
					printf "${BOLD}NTP Redirect has been ${GRNct}ENABLED${CLRct}\n\n"
				fi
				PressEnter
				break
			;;
			3)
				_Menu_TimeServerOptions_
				break
			;;
			4)
				_Menu_DatabaseOptions_
				break
			;;
			u)
				printf "\n"
				if Check_Lock menu
				then
					Update_Version
					Clear_Lock
				fi
				PressEnter
				break
			;;
			uf)
				printf "\n"
				if Check_Lock menu
				then
					Update_Version force
					Clear_Lock
				fi
				PressEnter
				break
			;;
			e)
				ScriptHeader true
				printf "\n${BOLD}Thanks for using %s!${CLRct}\n\n\n" "$SCRIPT_NAME"
				exit 0
			;;
			z)
				while true
				do
					printf "\n${BOLD}Are you sure you want to uninstall %s? (y/n)${CLRct}  " "$SCRIPT_NAME"
					read -r confirm
					case "$confirm" in
						y|Y)
							Menu_Uninstall
							exit 0
						;;
						*)
							break
						;;
					esac
				done
			;;
			*)
				_HandleInvalidMenuOption_
				PressEnter
				break
			;;
		esac
	done

	ScriptHeader true
	MainMenu
}

Check_Requirements()
{
	CHECKSFAILED="false"

	if [ "$(nvram get jffs2_scripts)" -ne 1 ]
	then
		nvram set jffs2_scripts=1
		nvram commit
		Print_Output true "Custom JFFS Scripts enabled" "$WARN"
	fi

	if [ ! -f /opt/bin/opkg ]
	then
		Print_Output false "Entware NOT detected!" "$CRIT"
		CHECKSFAILED="true"
	fi

	if ! Firmware_Version_Check
	then
		Print_Output false "Unsupported firmware version detected" "$CRIT"
		Print_Output false "$SCRIPT_NAME requires Merlin 384.15/384.13_4 or Fork 43E5 (or later)" "$ERR"
		CHECKSFAILED="true"
	fi

	NTP_Firmware_Check

	if [ "$CHECKSFAILED" = "false" ]
	then
		Print_Output false "Installing required packages from Entware" "$PASS"
		opkg update
		opkg install sqlite3-cli
		opkg install ntp-utils
		opkg install ntpd
		opkg install findutils
		return 0
	else
		return 1
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-15] ##
##----------------------------------------##
Menu_Install()
{
	ScriptHeader
	Print_Output true "Welcome to $SCRIPT_NAME $SCRIPT_VERSION, a script by JackYaz" "$PASS"
	sleep 1

	Print_Output false "Checking your router meets the requirements for $SCRIPT_NAME" "$PASS"

	if ! Check_Requirements
	then
		Print_Output false "Requirements for $SCRIPT_NAME not met, please see above for the reason(s)" "$CRIT"
		PressEnter
		Clear_Lock
		rm -f "/jffs/scripts/$SCRIPT_NAME_LOWER" 2>/dev/null
		exit 1
	fi

	Create_Dirs
	Conf_Exists
	Set_Version_Custom_Settings local "$SCRIPT_VERSION"
	Set_Version_Custom_Settings server "$SCRIPT_VERSION"
	ScriptStorageLocation load
	Create_Symlinks

	Update_File ntp.conf
	Update_File ntpdstats_www.asp
	Update_File shared-jy.tar.gz
	Update_File timeserverd

	Auto_Startup create 2>/dev/null
	Auto_Cron create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	Shortcut_Script create
	TimeServer_Customise

	{
	   echo "PRAGMA temp_store=1;"
	   echo "PRAGMA journal_mode=TRUNCATE;"
	   echo "CREATE TABLE IF NOT EXISTS [ntpstats] ([StatID] INTEGER PRIMARY KEY NOT NULL,[Timestamp] NUMERIC NOT NULL,[Offset] REAL NOT NULL,[Frequency] REAL NOT NULL,[Sys_Jitter] REAL NOT NULL,[Clk_Jitter] REAL NOT NULL,[Clk_Wander] REAL NOT NULL,[Rootdisp] REAL NOT NULL);" 
	} > /tmp/ntpMerlin-stats.sql
	_ApplyDatabaseSQLCmds_ /tmp/ntpMerlin-stats.sql ins1
	rm -f /tmp/ntpMerlin-stats.sql

	touch "$SCRIPT_STORAGE_DIR/lastx.csv"
	Process_Upgrade

	Get_TimeServer_Stats
	Clear_Lock

	ScriptHeader true
	MainMenu
}

##-------------------------------------##
## Added by Martinski W. [2025-Nov-04] ##
##-------------------------------------##
_SetParameters_()
{
    if [ -f "/opt/share/$SCRIPT_NAME_LOWER.d/config" ]
    then SCRIPT_STORAGE_DIR="/opt/share/$SCRIPT_NAME_LOWER.d"
    else SCRIPT_STORAGE_DIR="/jffs/addons/$SCRIPT_NAME_LOWER.d"
    fi
    SCRIPT_CONF="$SCRIPT_STORAGE_DIR/config"
    NTPDSTATS_DB="$SCRIPT_STORAGE_DIR/ntpdstats.db"
    CSV_OUTPUT_DIR="$SCRIPT_STORAGE_DIR/csv"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jul-30] ##
##----------------------------------------##
Menu_Startup()
{
	if [ $# -eq 0 ] || [ -z "$1" ]
	then
		Print_Output true "Missing argument for startup, not starting $SCRIPT_NAME" "$ERR"
		exit 1
	elif [ "$1" != "force" ]
	then
		if [ ! -x "${1}/entware/bin/opkg" ]
		then
			Print_Output true "$1 does NOT contain Entware, not starting $SCRIPT_NAME" "$CRIT"
			exit 1
		else
			Print_Output true "$1 contains Entware, $SCRIPT_NAME $SCRIPT_VERSION starting up" "$PASS"
		fi
	fi

	NTP_Ready
	Entware_Ready
	_SetParameters_
	Check_Lock

	if [ "$1" != "force" ]; then
		sleep 7
	fi

	Create_Dirs
	Conf_Exists
	ScriptStorageLocation load true
	Create_Symlinks
	Auto_Startup create 2>/dev/null
	Auto_Cron create 2>/dev/null
	Set_Version_Custom_Settings local "$SCRIPT_VERSION"
	Auto_ServiceEvent create 2>/dev/null
	NTP_Firmware_Check
	Shortcut_Script create
	Mount_WebUI
	TimeServer_ServiceCheck
	Clear_Lock
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-15] ##
##----------------------------------------##
Menu_Edit()
{
	local textEditor=""  exitMenu=false  retCode  CONF_FILE

	printf "\n${BOLD}A choice of text editors is available:${CLRct}\n\n"
	printf "  ${GRNct}1${CLRct}. nano (recommended for beginners)\n"
	printf "  ${GRNct}2${CLRct}. vi\n\n"
	printf "  ${GRNct}e${CLRct}. Go back\n"

	while true
	do
		printf "\n${BOLD}Choose an option:${CLRct}  "
		read -r editorOption
		case "$editorOption" in
			1) textEditor="nano -K" ; break
			   ;;
			2) textEditor="vi" ; break
			   ;;
			e) exitMenu=true ; break
			   ;;
			*)
				if [ -z "$editorOption" ]
				then exitMenu=true ; break
				fi
				printf "\n Please choose a valid option\n\n"
			;;
		esac
	done

	if "$exitMenu"
	then
		echo ; retCode=1
	else
		TIMESERVER_NAME="$(TimeServer check)"
		CONF_FILE=""
		if [ "$TIMESERVER_NAME" = "ntpd" ]
		then
			CONF_FILE="$SCRIPT_STORAGE_DIR/ntp.conf"
		elif [ "$TIMESERVER_NAME" = "chronyd" ]
		then
			CONF_FILE="$SCRIPT_STORAGE_DIR/chrony.conf"
		fi
		oldmd5="$(md5sum "$CONF_FILE" | awk '{print $1}')"
		$textEditor "$CONF_FILE"
		newmd5="$(md5sum "$CONF_FILE" | awk '{print $1}')"
		if [ "$oldmd5" != "$newmd5" ]
		then
			"/opt/etc/init.d/S77$TIMESERVER_NAME" restart >/dev/null 2>&1
		fi
		echo ; retCode=0
	fi
	Clear_Lock
	return "$retCode"
}

Menu_ResetDB()
{
	printf "${BOLD}${WARN}WARNING: This will reset the %s database by deleting all database records.\n" "$SCRIPT_NAME"
	printf "A backup of the database will be created if you change your mind.${CLEARFORMAT}\n"
	printf "\n${BOLD}Do you want to continue? (y/n)${CLEARFORMAT}  "
	read -r confirm
	case "$confirm" in
		y|Y)
			printf "\n"
			Reset_DB
		;;
		*)
			printf "\n${BOLD}${WARN}Database reset cancelled${CLEARFORMAT}\n\n"
		;;
	esac
}

##-------------------------------------##
## Added by Martinski W. [2025-Feb-16] ##
##-------------------------------------##
_RemoveMenuAddOnsSection_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ] || \
      ! echo "$1" | grep -qE "^[1-9][0-9]*$" || \
      ! echo "$2" | grep -qE "^[1-9][0-9]*$" || \
      [ "$1" -ge "$2" ]
   then return 1 ; fi
   local BEGINnum="$1"  ENDINnum="$2"

   if [ -n "$(sed -E "${BEGINnum},${ENDINnum}!d;/${webPageLineTabExp}/!d" "$TEMP_MENU_TREE")" ]
   then return 1
   fi
   sed -i "${BEGINnum},${ENDINnum}d" "$TEMP_MENU_TREE"
   return 0
}

##-------------------------------------##
## Added by Martinski W. [2025-Feb-16] ##
##-------------------------------------##
_FindandRemoveMenuAddOnsSection_()
{
   local BEGINnum  ENDINnum  retCode=1

   if grep -qE "^${BEGIN_MenuAddOnsTag}$" "$TEMP_MENU_TREE" && \
      grep -qE "^${ENDIN_MenuAddOnsTag}$" "$TEMP_MENU_TREE"
   then
       BEGINnum="$(grep -nE "^${BEGIN_MenuAddOnsTag}$" "$TEMP_MENU_TREE" | awk -F ':' '{print $1}')"
       ENDINnum="$(grep -nE "^${ENDIN_MenuAddOnsTag}$" "$TEMP_MENU_TREE" | awk -F ':' '{print $1}')"
       _RemoveMenuAddOnsSection_ "$BEGINnum" "$ENDINnum" && retCode=0
   fi

   if grep -qE "^${webPageMenuAddons}$" "$TEMP_MENU_TREE" && \
      grep -qE "${webPageHelpSupprt}$" "$TEMP_MENU_TREE"
   then
       BEGINnum="$(grep -nE "^${webPageMenuAddons}$" "$TEMP_MENU_TREE" | awk -F ':' '{print $1}')"
       ENDINnum="$(grep -nE "${webPageHelpSupprt}$" "$TEMP_MENU_TREE" | awk -F ':' '{print $1}')"
       if [ -n "$BEGINnum" ] && [ -n "$ENDINnum" ] && [ "$BEGINnum" -lt "$ENDINnum" ]
       then
           BEGINnum="$((BEGINnum - 2))" ; ENDINnum="$((ENDINnum + 3))"
           if [ "$(sed -n "${BEGINnum}p" "$TEMP_MENU_TREE")" = "," ] && \
              [ "$(sed -n "${ENDINnum}p" "$TEMP_MENU_TREE")" = "}" ]
           then
               _RemoveMenuAddOnsSection_ "$BEGINnum" "$ENDINnum" && retCode=0
           fi
       fi
   fi
   return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jul-31] ##
##----------------------------------------##
Menu_Uninstall()
{
	if [ -n "$PPID" ]; then
		ps | grep -v grep | grep -v $$ | grep -v "$PPID" | grep -i "$SCRIPT_NAME" | grep generate | awk '{print $1}' | xargs kill -9 >/dev/null 2>&1
	else
		ps | grep -v grep | grep -v $$ | grep -i "$SCRIPT_NAME" | grep generate | awk '{print $1}' | xargs kill -9 >/dev/null 2>&1
	fi
	Print_Output true "Removing $SCRIPT_NAME..." "$PASS"
	Auto_Startup delete 2>/dev/null
	Auto_Cron delete 2>/dev/null
	Auto_ServiceEvent delete 2>/dev/null
	Auto_NAT delete
	NTP_Redirect delete

	LOCKFILE=/tmp/addonwebui.lock
	FD=386
	eval exec "$FD>$LOCKFILE"
	flock -x "$FD"

	Get_WebUI_Page "$SCRIPT_DIR/ntpdstats_www.asp"
	if [ -n "$MyWebPage" ] && \
	   [ "$MyWebPage" != "NONE" ] && \
	   [ -f "$TEMP_MENU_TREE" ]
	then
		sed -i "\\~$MyWebPage~d" "$TEMP_MENU_TREE"
		rm -f "$SCRIPT_WEBPAGE_DIR/$MyWebPage"
		rm -f "$SCRIPT_WEBPAGE_DIR/$(echo "$MyWebPage" | cut -f1 -d'.').title"
		_FindandRemoveMenuAddOnsSection_
		umount /www/require/modules/menuTree.js
		mount -o bind "$TEMP_MENU_TREE" /www/require/modules/menuTree.js
	fi

	flock -u "$FD"
	rm -f "$SCRIPT_DIR/ntpdstats_www.asp" 2>/dev/null
	rm -rf "$SCRIPT_WEB_DIR" 2>/dev/null

	Shortcut_Script delete

    if [ -f /opt/etc/init.d/S77ntpd ]
	then
		/opt/etc/init.d/S77ntpd stop >/dev/null 2>&1
		sleep 2 ; killall -q ntpd ; sleep 1
	fi
	if [ -f /opt/etc/init.d/S77chronyd ]
	then
		/opt/etc/init.d/S77chronyd stop >/dev/null 2>&1
		sleep 2 ; killall -q chronyd ; sleep 1
	fi

	opkg remove --autoremove ntpd
	opkg remove --autoremove ntp-utils
	opkg remove --autoremove chrony

	rm -f /opt/etc/init.d/S77ntpd
	rm -f /opt/etc/init.d/S77chronyd
	rm -f "$SCRIPT_DIR"/S77*d

	SETTINGSFILE="/jffs/addons/custom_settings.txt"
	sed -i '/ntpmerlin_version_local/d' "$SETTINGSFILE"
	sed -i '/ntpmerlin_version_server/d' "$SETTINGSFILE"

	printf "\\n${BOLD}Do you want to delete %s configuration file and stats? (y/n)${CLEARFORMAT}  " "$SCRIPT_NAME"
	read -r confirm
	case "$confirm" in
		y|Y)
			rm -rf "$SCRIPT_DIR" 2>/dev/null
			rm -rf "$SCRIPT_STORAGE_DIR" 2>/dev/null
		;;
		*)
			:
		;;
	esac

	rm -f "/jffs/scripts/$SCRIPT_NAME_LOWER" 2>/dev/null
	Clear_Lock
	Print_Output true "Uninstall completed" "$PASS"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-28] ##
##----------------------------------------##
NTP_Ready()
{
	local theSleepDelay=15  ntpMaxWaitSecs=600  ntpWaitSecs

	if [ "$(nvram get ntp_ready)" -eq 0 ]
	then
		Check_Lock
		ntpWaitSecs=0
		Print_Output true "Waiting for NTP to sync..." "$WARN"

		while [ "$(nvram get ntp_ready)" -eq 0 ] && [ "$ntpWaitSecs" -lt "$ntpMaxWaitSecs" ]
		do
			if [ "$ntpWaitSecs" -gt 0 ] && [ "$((ntpWaitSecs % 30))" -eq 0 ]
			then
			    Print_Output true "Waiting for NTP to sync [$ntpWaitSecs secs]..." "$WARN"
			fi
			sleep "$theSleepDelay"
			ntpWaitSecs="$((ntpWaitSecs + theSleepDelay))"
		done

		if [ "$ntpWaitSecs" -ge "$ntpMaxWaitSecs" ]
		then
			Print_Output true "NTP failed to sync after 10 minutes. Please resolve!" "$CRIT"
			Clear_Lock
			exit 1
		else
			Print_Output true "NTP has synced [$ntpWaitSecs secs]. $SCRIPT_NAME will now continue." "$PASS"
			Clear_Lock
		fi
	fi
}

### function based on @Adamm00's Skynet USB wait function ###
##----------------------------------------##
## Modified by Martinski W. [2025-Feb-28] ##
##----------------------------------------##
Entware_Ready()
{
	local theSleepDelay=5  maxSleepTimer=120  sleepTimerSecs

	if [ ! -f /opt/bin/opkg ]
	then
		Check_Lock
		sleepTimerSecs=0

		while [ ! -f /opt/bin/opkg ] && [ "$sleepTimerSecs" -lt "$maxSleepTimer" ]
		do
			if [ "$((sleepTimerSecs % 10))" -eq 0 ]
			then
			    Print_Output true "Entware NOT found. Wait for Entware to be ready [$sleepTimerSecs secs]..." "$WARN"
			fi
			sleep "$theSleepDelay"
			sleepTimerSecs="$((sleepTimerSecs + theSleepDelay))"
		done

		if [ ! -f /opt/bin/opkg ]
		then
			Print_Output true "Entware NOT found and is required for $SCRIPT_NAME to run, please resolve!" "$CRIT"
			Clear_Lock
			exit 1
		else
			Print_Output true "Entware found [$sleepTimerSecs secs]. $SCRIPT_NAME will now continue." "$PASS"
			Clear_Lock
		fi
	fi
}

### function based on @dave14305's FlexQoS about function ###
##----------------------------------------##
## Modified by Martinski W. [2025-May-14] ##
##----------------------------------------##
Show_About()
{
	printf "About ${MGNTct}${SCRIPT_VERS_INFO}${CLRct}\n"
	cat <<EOF
  $SCRIPT_NAME implements an NTP time server for AsusWRT Merlin
  with charts for daily, weekly and monthly summaries of performance.
  A choice between ntpd and chrony is available.

License
  $SCRIPT_NAME is free to use under the GNU General Public License
  version 3 (GPL-3.0) https://opensource.org/licenses/GPL-3.0

Help & Support
  https://www.snbforums.com/forums/asuswrt-merlin-addons.60/?prefix_id=22

Source code
  https://github.com/AMTM-OSR/$SCRIPT_NAME
EOF
	printf "\n"
}

### function based on @dave14305's FlexQoS show_help function ###
##----------------------------------------##
## Modified by Martinski W. [2025-May-14] ##
##----------------------------------------##
Show_Help()
{
	printf "HELP ${MGNTct}${SCRIPT_VERS_INFO}${CLRct}\n"
	cat <<EOF
Available commands:
  $SCRIPT_NAME_LOWER about            explains functionality
  $SCRIPT_NAME_LOWER update           checks for updates
  $SCRIPT_NAME_LOWER forceupdate      updates to latest version (force update)
  $SCRIPT_NAME_LOWER startup force    runs startup actions such as mount WebUI tab
  $SCRIPT_NAME_LOWER install          installs script
  $SCRIPT_NAME_LOWER uninstall        uninstalls script
  $SCRIPT_NAME_LOWER generate         get modem stats and logs. also runs outputcsv
  $SCRIPT_NAME_LOWER outputcsv        create CSVs from database, used by WebUI and export
  $SCRIPT_NAME_LOWER ntpredirect      apply firewall rules to intercept and redirect NTP traffic
  $SCRIPT_NAME_LOWER develop          switch to development branch version
  $SCRIPT_NAME_LOWER stable           switch to stable/production branch version
EOF
	printf "\n"
}

##-------------------------------------##
## Added by Martinski W. [2025-Jan-04] ##
##-------------------------------------##
TMPDIR="$SHARE_TEMP_DIR"
SQLITE_TMPDIR="$TMPDIR"
export SQLITE_TMPDIR TMPDIR

if [ -d "$TMPDIR" ]
then sqlDBLogFilePath="${TMPDIR}/$sqlDBLogFileName"
else sqlDBLogFilePath="/tmp/var/tmp/$sqlDBLogFileName"
fi
_SQLCheckDBLogFileSize_

_SetParameters_
JFFS_LowFreeSpaceStatus="OK"
updateJFFS_SpaceInfo=false

if [ "$SCRIPT_BRANCH" = "master" ]
then SCRIPT_VERS_INFO=""
else SCRIPT_VERS_INFO="[$versionDev_TAG]"
fi

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-15] ##
##----------------------------------------##
if [ $# -eq 0 ] || [ -z "$1" ]
then
	NTP_Ready
	Entware_Ready
	if [ ! -f /opt/bin/sqlite3 ] && [ -x /opt/bin/opkg ]
	then
		Print_Output true "Installing required version of sqlite3 from Entware" "$PASS"
		opkg update
		opkg install sqlite3-cli
	fi
	Create_Dirs
	Conf_Exists
	ScriptStorageLocation load
	Create_Symlinks
	Auto_Startup create 2>/dev/null
	Auto_Cron create 2>/dev/null
	Set_Version_Custom_Settings local "$SCRIPT_VERSION"
	Auto_ServiceEvent create 2>/dev/null
	Shortcut_Script create
	_CheckFor_WebGUI_Page_
	Process_Upgrade
	ScriptHeader true
	MainMenu
	exit 0
fi

##----------------------------------------##
## Modified by Martinski W. [2026-Feb-18] ##
##----------------------------------------##
case "$1" in
	install)
		Check_Lock
		Menu_Install
		exit 0
	;;
	startup)
		shift
		Menu_Startup "$@"
		exit 0
	;;
	generate)
		NTP_Ready
		Entware_Ready
		TimeServer_ServiceCheck false
		Check_Lock
		Get_TimeServer_Stats
		Clear_Lock
		exit 0
	;;
	outputcsv)
		NTP_Ready
		Entware_Ready
		Check_Lock
		Generate_CSVs
		Clear_Lock
		exit 0
	;;
	trimdb)
		NTP_Ready
		Entware_Ready
		Check_Lock
		_Trim_Database_
		_Optimize_Database_
		_UpdateDatabaseFileSizeInfo_
		Clear_Lock
		exit 0
	;;
	service_event)
		updateJFFS_SpaceInfo=true
		if [ "$2" = "start" ] && [ "$3" = "$SCRIPT_NAME_LOWER" ]
		then
			rm -f /tmp/detect_ntpmerlin.js
			TimeServer_ServiceCheck
			Check_Lock webui
			sleep 2
			Get_TimeServer_Stats
			updateJFFS_SpaceInfo=false
			Clear_Lock
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME_LOWER}config" ]
		then
			Conf_FromSettings
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME_LOWER}checkupdate" ]
		then
			Update_Check
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME_LOWER}doupdate" ]
		then
			Update_Version force unattended
		fi
		"$updateJFFS_SpaceInfo" && _UpdateJFFS_FreeSpaceInfo_
		exit 0
	;;
	ntpredirect)
		Print_Output true "Sleeping for 5s to allow firewall/nat startup to be completed..." "$PASS"
		sleep 5
		Auto_NAT create
		NTP_Redirect create
		exit 0
	;;
	update)
		Update_Version
		exit 0
	;;
	forceupdate)
		Update_Version force
		exit 0
	;;
	amtmupdate)
		shift
		ScriptUpdateFromAMTM "$@"
		exit "$?"
	;;
	postupdate)
		Create_Dirs
		Conf_Exists
		ScriptStorageLocation load true
		Create_Symlinks
		Auto_Startup create 2>/dev/null
		Auto_Cron create 2>/dev/null
		Auto_ServiceEvent create 2>/dev/null
		Process_Upgrade
		if Auto_NAT check ; then NTP_Redirect create ; fi
		Shortcut_Script create
		Set_Version_Custom_Settings local "$SCRIPT_VERSION"
		Set_Version_Custom_Settings server "$SCRIPT_VERSION"
		exit 0
	;;
	checkupdate)
		Update_Check
		exit 0
	;;
	uninstall)
		Menu_Uninstall
		exit 0
	;;
	about)
		ScriptHeader true
		Show_About
		exit 0
	;;
	help)
		ScriptHeader true
		Show_Help
		exit 0
	;;
	develop)
		SCRIPT_BRANCH="develop"
		SCRIPT_REPO="https://raw.githubusercontent.com/AMTM-OSR/$SCRIPT_NAME/$SCRIPT_BRANCH"
		Update_Version force
		exit 0
	;;
	stable)
		SCRIPT_BRANCH="master"
		SCRIPT_REPO="https://raw.githubusercontent.com/AMTM-OSR/$SCRIPT_NAME/$SCRIPT_BRANCH"
		Update_Version force
		exit 0
	;;
	*)
		ScriptHeader
		Print_Output false "Parameter [$*] is NOT recognised." "$ERR"
		Print_Output false "For a list of available commands run: $SCRIPT_NAME_LOWER help" "$SETTING"
		exit 1
	;;
esac
