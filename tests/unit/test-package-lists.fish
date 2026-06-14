#!/usr/bin/env fish

source (dirname (dirname (status filename)))/lib/test-utils.fish

test_reset_counters
test_section "package name parsing"

set -l raw (aur_parse_pkg_names (cat (test_fixture_path arch-list.html)) | string collect)
assert_contains "html tag stripped" beef "$raw"
assert_contains "valid pkg kept" extra-pkg "$raw"
assert_contains "known-bad kept" known-bad "$raw"
assert_not_match "invalid html rejected" '(^|\n)not valid' "$raw"

set -l cscs_raw (aur_parse_cscs_script (test_fixture_path cscs-list.sh) | string collect)
assert_contains "cscs beef" beef "$cscs_raw"
assert_contains "cscs known-bad" known-bad "$cscs_raw"
assert_not_match "cscs script tag rejected" 'alert' "$cscs_raw"
assert_not_match "cscs invalid name rejected" 'invalid pkg name' "$cscs_raw"

test_section "list delta via comm temp files"
set -l old_list (mktemp)
set -l new_list (mktemp)
printf '%s\n' alpha beef gamma >$old_list
printf '%s\n' alpha beta beef >$new_list

set -l old_sorted (mktemp)
set -l new_sorted (mktemp)
sort -u $old_list >$old_sorted
sort -u $new_list >$new_sorted
set -l added (comm -13 $old_sorted $new_sorted)
set -l removed (comm -23 $old_sorted $new_sorted)
assert_count "added beta" 1 $added
assert_eq "added pkg name" beta $added[1]
assert_count "removed gamma" 1 $removed
assert_eq "removed pkg name" gamma $removed[1]

set -g AUR_SUMMARY_list_added 0
set -g AUR_SUMMARY_list_removed 0
set -l _quiet $AUR_OPT_quiet
set -g AUR_OPT_quiet true
aur_list_delta $old_list alpha beta beef
set -g AUR_OPT_quiet $_quiet
assert_eq "aur_list_delta added count" 1 $AUR_SUMMARY_list_added
assert_eq "aur_list_delta removed count" 1 $AUR_SUMMARY_list_removed

rm -f $old_list $new_list $old_sorted $new_sorted

test_section "installed vs infected intersection"
set -l installed (mktemp)
set -l infected (mktemp)
printf '%s\n' bee beef foo >$installed
printf '%s\n' beef evil-pkg >$infected
sort -u $installed >$installed.s
sort -u $infected >$infected.s
set -l found (comm -12 $installed.s $infected.s)
assert_count "exact comm match" 1 $found
assert_eq "only beef matches" beef $found[1]
rm -f $installed $infected $installed.s $infected.s

test_finish "test-package-lists.fish"
exit $status
