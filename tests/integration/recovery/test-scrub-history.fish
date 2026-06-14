#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "scrub-history dry-run"

set -l tmp_home (mktemp -d)
mkdir -p $tmp_home/.local/share/fish
cp (test_fixture_path history/history-secrets.txt) $tmp_home/.local/share/fish/fish_history

set -l out_file (mktemp)
env HOME=$tmp_home fish (aur_script_path recovery/scrub-history.fish) --dry-run >$out_file 2>&1
assert_eq "scrub dry-run exits 0" 0 $status
set -l out (cat $out_file)
assert_match "reports matched lines" '2 matched' "$out"
assert_match "dry-run banner" '\[--dry-run\]' "$out"

set -l lines (count (cat $tmp_home/.local/share/fish/fish_history))
assert_eq "dry-run leaves history untouched" 4 $lines

test_section "scrub-history unknown flag"
set -l bad_file (mktemp)
env HOME=$tmp_home fish (aur_script_path recovery/scrub-history.fish) --nope >$bad_file 2>&1
assert_eq "scrub unknown flag exits 4" $AUR_EXIT_INVALID $status
rm -f $bad_file

rm -rf $tmp_home $out_file

test_finish "test-scrub-history.fish"
exit $status
