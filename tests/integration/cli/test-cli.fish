#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "unknown flags exit 4"

function assert_unknown_flag --argument-names label script
    set -l out_file (mktemp)
    fish $AUR_SCRIPTS_DIR/$script --not-a-real-flag >$out_file 2>&1
    assert_eq "$label" $AUR_EXIT_INVALID $status
    rm -f $out_file
end

assert_unknown_flag scan/atomic-arch-timeline scan/atomic-arch-timeline.fish
assert_unknown_flag scan-aur-window scan/aur-window.fish
assert_unknown_flag scan-malware-artifacts scan/malware-artifacts.fish
assert_unknown_flag scan-similar-heuristics scan/similar-heuristics.fish
assert_unknown_flag check-list-freshness check/list-freshness.fish
assert_unknown_flag scan-hardening scan/hardening.fish
assert_unknown_flag apply-hardening recovery/apply-hardening.fish
assert_unknown_flag check/atomic-arch-pkgs check/atomic-arch-pkgs.fish
assert_unknown_flag audit-stolen-credentials audit/stolen-credentials.fish
assert_unknown_flag rotate-hints recovery/rotate-hints.fish
assert_unknown_flag scrub-history recovery/scrub-history.fish

test_section "known flags accepted"

set -l out_file (mktemp)
fish (aur_script_path scan/atomic-arch-timeline.fish) --help >$out_file 2>&1
set -l out (cat $out_file)
assert_eq "scan/atomic-arch-timeline --help" 0 $status
assert_match "help mentions window dates" 'Jun 9' "$out"
rm -f $out_file

begin
    fish (aur_script_path check/atomic-arch-pkgs.fish) --all-time --help >/dev/null 2>&1
    assert_status "check/atomic-arch-pkgs --all-time accepted" 0
end

test_finish "test-cli.fish"
exit $status
