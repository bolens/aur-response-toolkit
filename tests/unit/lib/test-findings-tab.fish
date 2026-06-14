#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "comma-safe timeline findings"

set -l _state $AUR_STATE_FILE
set -l _reports $AUR_REPORTS_DIR
set -g AUR_REPORTS_DIR (mktemp -d)
set -gx AUR_STATE_FILE "$AUR_REPORTS_DIR/.scan-state"
aur_state_init
aur_finding_add atomic_arch_timeline_hits "installed foo, upgraded bar, reinstalled baz"
set -l hits (aur_finding_list atomic_arch_timeline_hits)
assert_eq "one timeline row" 1 (count $hits)
assert_eq "commas preserved" "installed foo, upgraded bar, reinstalled baz" $hits[1]

test_section "duplicate finding dedup"
aur_finding_add atomic_arch_installed dup-pkg
aur_finding_add atomic_arch_installed dup-pkg
set -l infected (aur_finding_list atomic_arch_installed)
assert_eq "deduped finding" 1 (count $infected)

rm -rf $AUR_REPORTS_DIR
set -g AUR_STATE_FILE $_state
set -g AUR_REPORTS_DIR $_reports

test_finish "test-findings-tab.fish"
exit $status
