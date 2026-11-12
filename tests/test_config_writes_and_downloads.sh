#!/bin/sh
# Runs the config check and web file updates from ntpmerlin.sh with a stubbed download.
# Usage: tests/test_config_writes_and_downloads.sh [path/to/ntpmerlin.sh]
S="$(cd "$(dirname "${1:-ntpmerlin.sh}")" && pwd)/$(basename "${1:-ntpmerlin.sh}")"
T="${TMPDIR:-/tmp}/pr-test.$$"; mkdir -p "$T" || exit 1; trap 'rm -rf "$T"' EXIT; rc=0; cd "$T" || exit 1
ok() { echo "PASS $1"; }; no() { echo "FAIL $1"; rc=1; }
check() { if eval "$2"; then ok "$1"; else no "$1"; fi; }
fn() { awk -v n="$1()" '$0==n{f=1} f{print} f&&/^}/{exit}' "$S"; }
ino() { ls -i "$1" | awk '{print $1}'; }

# A clean config isn't rewritten; one that needs cleaning still is.
eval "$(fn Conf_Exists)"; SCRIPT_CONF=conf
printf 'OUTPUTTIMEMODE=unix\nDAYSTOKEEP=30\nLASTXRESULTS=10\nSTORAGELOCATION=jffs\nJFFS_MSGLOGTIME=0\nTIMESERVER=ntpd\n' > conf
before=$(ino conf); Conf_Exists
check "clean config isn't rewritten" "[ \"\$(ino conf)\" = '$before' ]"
printf 'OUTPUTTIMEMODE="unix"\r\nDAYSTOKEEP=30\r\nLASTXRESULTS=10\r\nSTORAGELOCATION=jffs\r\nJFFS_MSGLOGTIME=0\r\nTIMESERVER=ntpd\r\n' > conf
Conf_Exists
check "line endings are still fixed" "! grep -q \"\$(printf '\\r')\" conf"
check "quotes are still removed" "grep -q '^OUTPUTTIMEMODE=unix$' conf"

# Update_File with a server that fails, or serves new content.
eval "$(fn Update_File)"; eval "$(fn Get_Shared_Archive)"
SCRIPT_DIR=$T/dir; SHARED_DIR=$T/shared; SCRIPT_REPO=repo; SHARED_REPO=repo; SCRIPT_NAME_LOWER=ntptest; SCRIPT_WEBPAGE_DIR=$T/www
MyWebPage=user1.asp; TEMP_MENU_TREE=$T/menu; PASS=; mkdir -p "$SCRIPT_DIR" "$SHARED_DIR" "$SCRIPT_WEBPAGE_DIR"; : > menu
Print_Output() { :; }; Get_WebUI_Page() { :; }; Mount_WebUI() { : > mounted; }

asp=ntpdstats_www.asp
echo installed > "$SCRIPT_DIR/$asp"; echo page > "$SCRIPT_WEBPAGE_DIR/$MyWebPage"
Download_File() { return 22; }
Update_File "$asp" > /dev/null 2>&1
check "failed page download keeps the page" "grep -q installed '$SCRIPT_DIR/$asp'"
check "failed page download keeps it mounted" "[ -e '$SCRIPT_WEBPAGE_DIR/$MyWebPage' ]"
Download_File() { echo new > "$2"; }
Update_File "$asp" > /dev/null 2>&1
check "good page download replaces the page" "grep -q new '$SCRIPT_DIR/$asp'"

# The archive and its hash, published together.
tgz=shared-jy.tar.gz; mkdir src; echo chart > src/chart.js; ( cd src && tar -czf "../$tgz" chart.js )
md5sum < "$tgz" | cut -d' ' -f1 > "$tgz.md5"
echo old > "$SHARED_DIR/$tgz.md5"
curl() { cat "$T/$tgz.md5"; }
Download_File() { case "$1" in *.md5) cp "$T/$tgz.md5" "$2" ;; *) return 22 ;; esac; }
Update_File "$tgz" > /dev/null 2>&1
check "failed archive download is retried later" "grep -q old '$SHARED_DIR/$tgz.md5'"
echo corrupt > bad.tgz
Download_File() { case "$1" in *.md5) cp "$T/$tgz.md5" "$2" ;; *) cp "$T/bad.tgz" "$2" ;; esac; }
Update_File "$tgz" > /dev/null 2>&1
check "archive not matching its hash isn't installed" "grep -q old '$SHARED_DIR/$tgz.md5' && [ ! -e '$SHARED_DIR/chart.js' ]"
Download_File() { case "$1" in *.md5) cp "$T/$tgz.md5" "$2" ;; *) cp "$T/$tgz" "$2" ;; esac; }
Update_File "$tgz" > /dev/null 2>&1
check "good archive is installed" "[ -e '$SHARED_DIR/chart.js' ] && cmp -s '$SHARED_DIR/$tgz.md5' '$T/$tgz.md5'"

sh -n "$S" && ok syntax || no syntax
exit $rc
