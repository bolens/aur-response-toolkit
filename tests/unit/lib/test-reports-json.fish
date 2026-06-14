#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "severity mapping"

assert_eq "compromise severity" critical (aur_compute_severity $AUR_EXIT_COMPROMISE)
assert_eq "warn severity" warning (aur_compute_severity $AUR_EXIT_WARN)
assert_eq "insufficient severity" insufficient (aur_compute_severity $AUR_EXIT_INSUFFICIENT)
assert_eq "clean severity" clean (aur_compute_severity $AUR_EXIT_CLEAN)
assert_eq "unknown exit maps clean" clean (aur_compute_severity 99)

test_section "json string array fallback"

assert_eq "empty array" '[]' (aur_json_string_array)
assert_eq "quotes in array" '["line with \"quotes\""]' (aur_json_string_array 'line with "quotes"')
assert_eq "tab in array" '["tab\there"]' (aur_json_string_array "tab	here")
assert_eq "backslash in array" '["back\\\\slash"]' (aur_json_string_array 'back\slash')

test_section "finding categories"

set -l _state $AUR_STATE_FILE
set -l _reports $AUR_REPORTS_DIR
set -g AUR_REPORTS_DIR (mktemp -d)
set -gx AUR_STATE_FILE "$AUR_REPORTS_DIR/.scan-state"
aur_state_init
aur_finding_add atomic_arch_timeline_hits hit-one
aur_finding_add atomic_arch_installed beef
aur_finding_add atomic_arch_timeline_hits hit-two
set -l cats (aur_finding_categories | string collect)
assert_count "two categories" 2 "$cats"
assert_contains "timeline category" atomic_arch_timeline_hits "$cats"
assert_contains "atomic_arch_installed category" atomic_arch_installed "$cats"

rm -rf $AUR_REPORTS_DIR
set -g AUR_STATE_FILE $_state
set -g AUR_REPORTS_DIR $_reports

test_section "file compromise window mtime"

set -l in_window (mktemp)
echo test >$in_window
touch -d 2026-06-10 $in_window 2>/dev/null; or true
begin
    aur_file_in_compromise_window $in_window
    assert_status "Jun 10 mtime in window" 0
end
set -l out_window (mktemp)
echo test >$out_window
touch -d 2026-06-01 $out_window 2>/dev/null; or true
begin
    aur_file_in_compromise_window $out_window
    assert_status "Jun 1 mtime outside window" 1
end
rm -f $in_window $out_window

test_finish "test-reports-json.fish"
exit $status
