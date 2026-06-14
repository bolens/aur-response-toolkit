#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "validate known flags"

begin
    aur_validate_known_flags --local --report --fail-on=compromise --fail-on=chaos-rat --fail-on=shai-hulud --fail-on=xeactor --chaos-rat --shai-hulud --xeactor --prune-days=7
    assert_status "known flags accepted" 0
end

set -l invalid_out (mktemp)
fish -c "source $AUR_RESPONSE_DIR/lib/common.fish; aur_validate_known_flags --bogus-flag" >$invalid_out 2>&1
assert_eq "unknown flag exits 4" $AUR_EXIT_INVALID $status
assert_match "unknown flag message" 'Unknown option: --bogus-flag' (cat $invalid_out)
rm -f $invalid_out

test_section "parse common args variants"

aur_parse_common_args --fail-on=none --prune-days=14 --if-compromised --quick
assert_eq "fail-on equals form" none $AUR_OPT_fail_on
assert_eq "prune-days equals form" 14 $AUR_OPT_prune_days
assert_eq if-compromised true $AUR_OPT_if_compromised
assert_eq quick true $AUR_OPT_quick

aur_parse_common_args --fail-on compromise --prune-days 30
assert_eq "fail-on two-token form" compromise $AUR_OPT_fail_on
assert_eq "prune-days two-token form" 30 $AUR_OPT_prune_days

aur_parse_common_args --fail-on:all
assert_eq "fail-on colon form" all $AUR_OPT_fail_on

test_section "finalize exit with fail-on none"

set -g AUR_OPT_fail_on none
assert_eq "compromise suppressed" $AUR_EXIT_CLEAN (aur_finalize_exit true false false | tail -1)
assert_eq "warn suppressed" $AUR_EXIT_CLEAN (aur_finalize_exit false true false | tail -1)
assert_eq "insufficient suppressed" $AUR_EXIT_CLEAN (aur_finalize_exit false false true | tail -1)
set -g AUR_OPT_fail_on all

test_section "list staleness"

set -l stale_file (mktemp)
echo stale >$stale_file
touch -d '10 days ago' $stale_file 2>/dev/null; or true
assert_eq "staleness days" 10 (aur_list_staleness_days $stale_file)
assert_eq "missing file staleness" -1 (aur_list_staleness_days /nonexistent/file)
rm -f $stale_file

test_finish "test-cli-args.fish"
exit $status
