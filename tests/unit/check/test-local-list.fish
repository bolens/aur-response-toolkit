#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "local atomic arch list load"

set -l _had_test_list false
if set -q AUR_TEST_LIST_FILE
    set -l _saved_list $AUR_TEST_LIST_FILE
    set _had_test_list true
end
set -l _quiet $AUR_OPT_quiet

test_set_fixture_list lists/atomic-arch-pkgs.txt
set -g AUR_OPT_quiet true

begin
    aur_load_atomic_arch_list true >/dev/null 2>&1
    assert_status "local list loads" 0
end
set -l pkgs (aur_load_atomic_arch_list true | string collect)
assert_contains "local list has beef" beef "$pkgs"
assert_contains "local list has known-bad" known-bad "$pkgs"
assert_eq "runtime hook matches fixture" (test_fixture_path lists/atomic-arch-pkgs.txt) (aur_atomic_arch_list_file_path)

set -l read_pkgs (aur_load_and_read_atomic_arch_list true | string collect)
assert_contains "read helper beef" beef "$read_pkgs"

test_section "local list missing file fails"

test_set_list_file (mktemp)/missing-atomic-arch-pkgs.txt
begin
    aur_load_atomic_arch_list true >/dev/null 2>&1
    assert_status "missing local list exits 1" 1
end

test_section "stale local list warning"

set -l stale_list (mktemp)
printf '%s\n' beef >$stale_list
touch -d '30 days ago' $stale_list 2>/dev/null; or true
test_set_list_file $stale_list
set -g AUR_OPT_quiet false
set -l stale_out (aur_load_atomic_arch_list true 2>&1 | string collect)
assert_match "stale list warning" 'WARN: bundled list is [0-9]+ days old' "$stale_out"

rm -f $stale_list
if test $_had_test_list = true
    set -gx AUR_TEST_LIST_FILE $_saved_list
else
    test_clear_list_file
end
set -g AUR_OPT_quiet $_quiet

test_finish "test-local-list.fish"
exit $status
