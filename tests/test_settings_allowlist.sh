#!/bin/sh
# Only known settings with valid values may reach the config file, which root sources.
# Usage: tests/test_settings_allowlist.sh [path/to/ntpmerlin.sh]
S="$(cd "$(dirname "${1:-ntpmerlin.sh}")" && pwd)/$(basename "${1:-ntpmerlin.sh}")"
T="${TMPDIR:-/tmp}/pr-test.$$"; mkdir -p "$T" || exit 1; trap 'rm -rf "$T"' EXIT; rc=0; cd "$T" || exit 1
check() { if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; rc=1; fi; }

awk '$0=="Conf_FromSettings()"{f=1} f{print} f&&/^}/{exit}' "$S" | sed "s#/jffs/addons/custom_settings.txt#$T/settings#;s#/tmp/ntpmerlin_settings.txt#$T/tmp#" > f.sh
cat > run <<F
SCRIPT_CONF=$T/conf; PASS=; . $T/f.sh
Print_Output() { :; }; TimeServer() { :; }; TimeServer_Customise() { :; }; Generate_CSVs() { :; }; Create_Symlinks() { :; }
ScriptStorageLocation() { :; }; _Check_JFFS_SpaceAvailable_() { return 0; }
Conf_FromSettings
F
printf 'OUTPUTTIMEMODE=start\nSTORAGELOCATION=start\nTIMESERVER=start\nDAYSTOKEEP=0\nLASTXRESULTS=0\nJFFS_MSGLOGTIME=0\n' > conf.start
merge() { cp conf.start conf; rm -f PWN; printf '%s\n' "$@" > settings; sh ./run >/dev/null 2>&1; }

# Every value the web page can send is applied.
for pair in outputtimemode:unix:OUTPUTTIMEMODE outputtimemode:non-unix:OUTPUTTIMEMODE \
	storagelocation:usb:STORAGELOCATION storagelocation:jffs:STORAGELOCATION \
	timeserver:ntpd:TIMESERVER timeserver:chronyd:TIMESERVER \
	daystokeep:1:DAYSTOKEEP daystokeep:365:DAYSTOKEEP lastxresults:5:LASTXRESULTS; do
	key=${pair%%:*}; rest=${pair#*:}; val=${rest%%:*}; name=${rest#*:}
	merge "ntpmerlin_$key $val"
	check "applies $key $val" "grep -qx '$name=$val' conf"
done

# Anything else leaves the config byte for byte as it was, and runs nothing when it's sourced.
while IFS= read -r line; do
	merge "$line"
	( . ./conf ) >/dev/null 2>&1
	check "refuses: $line" 'cmp -s conf conf.start && [ ! -e PWN ]'
done <<'L'
ntpmerlin_lastxresults $(touch${IFS}PWN)
ntpmerlin_daystokeep `touch${IFS}PWN`
ntpmerlin_daystokeep 1;touch${IFS}PWN
ntpmerlin_daystokeep 1&&touch${IFS}PWN
ntpmerlin_daystokeep -5
ntpmerlin_daystokeep 1.5
ntpmerlin_daystokeep 0x10
ntpmerlin_daystokeep ten
ntpmerlin_lastxresults
ntpmerlin_timeserver x/;s/q/q
ntpmerlin_timeserver chronyd;touch${IFS}PWN
ntpmerlin_timeserver $(touch${IFS}PWN)
ntpmerlin_timeserver NTPD
ntpmerlin_timeserver
ntpmerlin_outputtimemode unix2
ntpmerlin_outputtimemode $(touch${IFS}PWN)
ntpmerlin_storagelocation /tmp/elsewhere
ntpmerlin_storagelocation usb;touch${IFS}PWN
ntpmerlin_jffs_msglogtime 1
ntpmerlin_unknownsetting 1
L

# A bad line doesn't stop the good ones around it.
merge 'ntpmerlin_daystokeep 45' 'ntpmerlin_lastxresults $(touch${IFS}PWN)' 'ntpmerlin_timeserver chronyd'
check "applies the value before a bad line" "grep -qx DAYSTOKEEP=45 conf"
check "applies the value after a bad line" "grep -qx TIMESERVER=chronyd conf"
check "keeps the old value for the bad line" "grep -qx LASTXRESULTS=0 conf"
check "bad value isn't written" "! grep -q touch conf"

# The merge consumes its input, so a refused value can't come back; other add-ons' settings stay.
merge 'ntpmerlin_version_local 1.0' 'other_addon_setting $(keep)' 'ntpmerlin_daystokeep $(touch${IFS}PWN)'
check "refused value is cleared from the settings file" "! grep -q ntpmerlin_daystokeep settings"
check "other add-ons' settings are kept" "grep -qF 'other_addon_setting \$(keep)' settings"
exit $rc
