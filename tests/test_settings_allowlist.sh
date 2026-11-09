#!/bin/sh
# Only known settings with valid values may reach the config file, which is sourced by root.
# Usage: tests/test_settings_allowlist.sh [path/to/ntpmerlin.sh]
S="${1:-ntpmerlin.sh}"; T="${TMPDIR:-/tmp}/pr-test.$$"; mkdir -p "$T" || exit 1; trap 'rm -rf "$T"' EXIT; rc=0
awk '$0=="Conf_FromSettings()"{f=1} f{print} f&&/^}/{exit}' "$S" | sed "s#/jffs/addons/custom_settings.txt#$T/settings#;s#/tmp/ntpmerlin_settings.txt#$T/tmp#" > "$T/f.sh"
printf 'OUTPUTTIMEMODE=unix\nSTORAGELOCATION=jffs\nTIMESERVER=chronyd\nDAYSTOKEEP=30\nLASTXRESULTS=10\n' > "$T/conf"
cat > "$T/settings" <<'L'
ntpmerlin_daystokeep 45
ntpmerlin_lastxresults $(touch${IFS}PWN)
ntpmerlin_timeserver x/;s/q/q
ntpmerlin_unknownsetting 1
L
cat > "$T/run" <<F
SCRIPT_CONF=$T/conf; PASS=; . $T/f.sh; Print_Output(){ :; }; TimeServer(){ :; }; TimeServer_Customise(){ :; }; Generate_CSVs(){ :; }; Create_Symlinks(){ :; }; Conf_FromSettings
F
sh "$T/run" >/dev/null 2>&1
grep -q '^DAYSTOKEEP=45$' "$T/conf" && echo "PASS valid value applied" || { echo "FAIL valid value applied"; rc=1; }
grep -q '^LASTXRESULTS=10$' "$T/conf" && echo "PASS injected number rejected" || { echo "FAIL injected number rejected"; rc=1; }
grep -q '^TIMESERVER=chronyd$' "$T/conf" && echo "PASS sed injection rejected" || { echo "FAIL sed injection rejected"; rc=1; }
exit $rc
