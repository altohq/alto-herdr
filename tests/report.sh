#!/bin/sh
# The reporter, against a herdr that writes down what it's asked: one
# case for each row of the mapping, and what it refuses to pass on.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fake="$work/herdr"
cat > "$fake" <<'EOF'
#!/bin/sh
for a in "$@"; do printf '[%s]' "$a"; done >> "$CALLS"
echo >> "$CALLS"
EOF
chmod +x "$fake"
failed=0

# Runs the reporter with these variables (NAME=VALUE ...), and says what
# herdr was asked, a line a call.
run() {
    : > "$work/calls"
    env -i PATH=/usr/bin:/bin CALLS="$work/calls" HERDR_BIN_PATH="$fake" HERDR_PANE_ID=w1:p2 \
        ALTO_REPORT_SESSION=studio:3 ALTO_REPORT_SEQ=1700000000123 "$@" "$here/bin/alto-herdr-report"
    cat "$work/calls"
}

expect() {
    name=$1 want=$2 got=$3
    if [ "$got" = "$want" ]; then
        echo "ok   $name"
    else
        echo "FAIL $name"
        echo "  want: $want"
        echo "  got:  $got"
        failed=1
    fi
}

report='[pane][report-agent][w1:p2][--source][alto][--agent][alto]'
resume='[--][alto][attach][--instead][studio:3]'
meta() { printf '[pane][report-metadata][w1:p2][--source][alto][--display-agent][%s][--token][host=studio]' "$1"; }

expect "working" "$report[--state][working][--seq][1700000000123]$resume
$(meta 'claude · studio:3')" "$(run ALTO_REPORT_STATE=working ALTO_REPORT_AGENT=claude ALTO_REPORT_KIND=agent)"

expect "needs-you is blocked, with why" "$report[--state][blocked][--seq][1700000000123][--message][permission: Bash]$resume
$(meta 'claude · studio:3')" "$(run ALTO_REPORT_STATE=needs-you ALTO_REPORT_NEED=permission 'ALTO_REPORT_WHY=permission: Bash' ALTO_REPORT_AGENT=claude)"

expect "done is idle" "$report[--state][idle][--seq][1700000000123]$resume
$(meta 'job · studio:3')" "$(run ALTO_REPORT_STATE=done ALTO_REPORT_KIND=job)"

expect "idle is idle" "$report[--state][idle][--seq][1700000000123]$resume
$(meta 'alto · studio:3')" "$(run ALTO_REPORT_STATE=idle)"

expect "ended is released" "[pane][release-agent][w1:p2][--source][alto][--agent][alto][--seq][1700000000123]" "$(run ALTO_REPORT_STATE=ended)"
expect "detached tells nothing" "" "$(run ALTO_REPORT_STATE=detached)"
expect "lost tells nothing" "" "$(run ALTO_REPORT_STATE=lost)"

# What it won't pass on.
expect "no pane: nothing" "" "$(run ALTO_REPORT_STATE=working HERDR_PANE_ID=)"
expect "an address that's an option: nothing" "" "$(run ALTO_REPORT_STATE=working ALTO_REPORT_SESSION=--help)"
expect "an address with a space: nothing" "" "$(run ALTO_REPORT_STATE=working 'ALTO_REPORT_SESSION=3 x')"
expect "a sequence that isn't a number: nothing" "" "$(run ALTO_REPORT_STATE=working ALTO_REPORT_SEQ=1x)"
expect "a why with control characters is one plain line" "$report[--state][blocked][--seq][1700000000123][--message][asks[2Jrm -rf]$resume
$(meta 'alto · studio:3')" "$(run ALTO_REPORT_STATE=needs-you "$(printf 'ALTO_REPORT_WHY=asks\033[2J\nrm -rf')")"
expect "an agent's name that isn't a word isn't shown" "$report[--state][working][--seq][1700000000123]$resume
$(meta 'agent · studio:3')" "$(run ALTO_REPORT_STATE=working 'ALTO_REPORT_AGENT=x;y' ALTO_REPORT_KIND=agent)"
expect "a session here" "$report[--state][working][--seq][1700000000123][--][alto][attach][--instead][3]
[pane][report-metadata][w1:p2][--source][alto][--display-agent][alto · 3][--token][host=here]" "$(run ALTO_REPORT_STATE=working ALTO_REPORT_SESSION=3)"

exit $failed
