#!/usr/bin/env fish

source (dirname (dirname (status filename)))/lib/test-utils.fish

test_reset_counters
test_section "report prune"

set -l _reports $AUR_REPORTS_DIR
set -g AUR_REPORTS_DIR (mktemp -d)
mkdir -p $AUR_REPORTS_DIR
echo old >$AUR_REPORTS_DIR/old-scan.log
touch -d '40 days ago' $AUR_REPORTS_DIR/old-scan.log 2>/dev/null; or true
echo fresh >$AUR_REPORTS_DIR/fresh-scan.log

aur_prune_reports 30
test -f $AUR_REPORTS_DIR/old-scan.log
assert_status "old report removed" 1
test -f $AUR_REPORTS_DIR/fresh-scan.log
assert_status "fresh report kept" 0

rm -rf $AUR_REPORTS_DIR
set -g AUR_REPORTS_DIR $_reports

test_finish "test-prune.fish"
exit $status
