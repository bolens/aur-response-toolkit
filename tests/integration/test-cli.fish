#!/usr/bin/env fish

source (dirname (dirname (status filename)))/lib/test-utils.fish

test_reset_counters
test_section "unknown flags exit 2"

function assert_unknown_flag --argument-names label script
    set -l out_file (mktemp)
    fish $AUR_SCRIPTS_DIR/$script --not-a-real-flag >$out_file 2>&1
    assert_eq "$label" 2 $status
    rm -f $out_file
end

assert_unknown_flag "scan-pacman-timeline" scan-pacman-timeline.fish
assert_unknown_flag "scan-aur-window" scan-aur-window.fish
assert_unknown_flag "scan-malware-artifacts" scan-malware-artifacts.fish
assert_unknown_flag "scan-hardening" scan-hardening.fish
assert_unknown_flag "check-infected-pkgs" check-infected-pkgs.fish
assert_unknown_flag "audit-stolen-credentials" audit-stolen-credentials.fish
assert_unknown_flag "rotate-hints" rotate-hints.fish
assert_unknown_flag "scrub-history" scrub-history.fish

test_section "known flags accepted"

set -l out_file (mktemp)
fish $AUR_SCRIPTS_DIR/scan-pacman-timeline.fish --help >$out_file 2>&1
set -l out (cat $out_file)
assert_eq "scan-pacman-timeline --help" 0 $status
assert_match "help mentions window dates" 'Jun 9' "$out"
rm -f $out_file

test_finish "test-cli.fish"
exit $status
