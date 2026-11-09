#!/bin/sh
# A failed download must leave the installed files alone; firewall rules must not pile up.
# Usage: tests/test_safe_downloads.sh [path/to/ntpmerlin.sh]
S="$(cd "$(dirname "${1:-ntpmerlin.sh}")" && pwd)/$(basename "${1:-ntpmerlin.sh}")"
T="${TMPDIR:-/tmp}/pr-test.$$"; mkdir -p "$T" || exit 1; trap 'rm -rf "$T"' EXIT; rc=0; cd "$T" || exit 1
ok() { echo "PASS $1"; }; no() { echo "FAIL $1"; rc=1; }
check() { if eval "$2"; then ok "$1"; else no "$1"; fi; }
fn() { awk -v n="$1()" '$0==n{f=1} f{print} f&&/^}/{exit}' "$S"; }

# A server answering 404: curl -f fails and saves nothing; plain curl saves the error page.
cat > curl.sh <<'C'
#!/bin/sh
case " $* " in *" -f"*) exit 22 ;; esac
while [ $# -gt 0 ]; do [ "$1" = -o ] && echo '404: Not Found' > "$2"; shift; done
exit 0
C
chmod +x curl.sh
fn Download_File | sed "s#/usr/sbin/curl#$T/curl.sh#" > dl.sh; . ./dl.sh
echo installed > keep; Download_File https://example.invalid/x keep; dlrc=$?
check "HTTP error fails the download" "[ $dlrc != 0 ]"
check "HTTP error keeps the file" "grep -q installed keep"

Print_Output() { :; }; killall() { :; }; sleep() { :; }; chown() { :; }; chmod() { :; }; ln() { :; }

# A failed self-update keeps the script.
mkdir scripts; SCRIPT_NAME=x; SCRIPT_NAME_LOWER=app; SCRIPT_REPO=https://example.invalid; PASS=
echo 'echo installed' > scripts/app
Download_File() { echo 'if (' > "$2"; return 0; }
grep -F 'Download_File "$SCRIPT_REPO/$SCRIPT_NAME_LOWER.sh"' "$S" | head -n 1 | sed "s#/jffs/scripts/#$T/scripts/#g; s/&& *\\\\\$/\& true/" > self.sh
. ./self.sh 2>/dev/null
check "broken self-update keeps the script" "grep -q 'echo installed' scripts/app"

# A failed init script download doesn't customise or restart the time server.
eval "$(fn Update_File)"; SCRIPT_DIR=$T/sd; mkdir sd; echo old > sd/S77chronyd
TimeServer_Customise() { echo customise >> trace; }; TimeServer_ServiceCheck() { echo check >> trace; }
Download_File() { return 22; }; Update_File S77chronyd
check "failed download doesn't reinstall the service" "! grep -q customise trace"
check "failed download checks the running service" "grep -q check trace"

# With no saved copy and no network, the real service check doesn't retry forever.
(
	eval "$(fn TimeServer_ServiceCheck)"; TimeServer() { echo chronyd; }; rm -f sd/S77chronyd
	Download_File() { echo x >> calls; [ "$(wc -l < calls)" -gt 5 ] && exit 9; return 22; }
	Update_File S77chronyd
) > /dev/null 2>&1
check "failed download doesn't loop" "[ \"\$(wc -l < calls)\" -le 2 ]"
echo old > sd/S77chronyd

# The time server keeps running with its init script when the replacement can't be fetched.
fn TimeServer_Customise | sed "s#/opt/etc/init.d/#$T/#g;s#/tmp/S77#$T/new.S77#g" > custom.sh; . ./custom.sh
printf '#!/bin/sh\necho "$1" >> %s/stopped\n' "$T" > S77chronyd; /bin/chmod +x S77chronyd
TimeServer() { echo chronyd; }; mkdir() { :; }; TimeServer_Customise > /dev/null 2>&1
check "init script kept when download fails" "[ -s S77chronyd ]"
check "time server not stopped when download fails" "[ ! -e stopped ]"
unset -f mkdir

# Repeated rule creation doesn't pile up REJECT rules.
fn NTP_Redirect > r.sh; . ./r.sh
iptables() { case "$*" in *-nvL*) echo '1 all state RELATED,ESTABLISHED' ;; *FORWARD*) echo "$1" >> ipt ;; esac; }
ip6tables() { :; }; nvram() { echo 192.0.2.1; }; Auto_DNSMASQ() { :; }
NTP_Redirect create > /dev/null 2>&1
check "old REJECT rules removed before insert" "[ \"\$(head -n 2 ipt | tr -d '\n')\" = -D-D ]"

exit $rc
