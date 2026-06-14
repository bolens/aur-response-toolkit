#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "triage unknown package states"

begin
    aur_triage_unknown_pkg definitely-not-installed-pkg-xyz >/dev/null 2>&1
    assert_status "missing pkg not critical" 1
end
set -l triage_missing (aur_triage_unknown_pkg definitely-not-installed-pkg-xyz | string collect)
assert_contains "missing pkg issue" "not currently installed" "$triage_missing"

set -l info_file (mktemp)
echo 'window-pkg|Mon 09 Jun 2026 10:00:00|Explicitly installed' >$info_file
set -gx AUR_TEST_PKG_INFO $info_file
set -g AUR_OPT_all_time false

set -l _home $HOME
set -l tmp_home (mktemp -d)
set -gx HOME $tmp_home
mkdir -p $HOME/.cache/paru/clone/window-pkg
cp (test_fixture_path pkgbuilds/pkgbuild.malicious) $HOME/.cache/paru/clone/window-pkg/PKGBUILD

set -l triage_cache (aur_triage_unknown_pkg window-pkg | string collect)
begin
    aur_triage_unknown_pkg window-pkg >/dev/null 2>&1
    assert_status "malicious cache triage critical" 0
end
assert_match "malicious hook flagged" 'malicious hook in cache:' "$triage_cache"

set -gx HOME $_home
set -e AUR_TEST_PKG_INFO
rm -f $info_file
rm -rf $tmp_home

test_section "extra persistence shell rc detection"

set -l _home $HOME
set -l tmp_home (mktemp -d)
set -gx HOME $tmp_home
printf '%s\n' 'npm install js-digest' >$HOME/.bashrc

set -l hits (aur_check_extra_persistence | string collect)
assert_status "shell rc persistence found" 0
assert_contains "bashrc flagged" "shell_rc:$HOME/.bashrc" "$hits"

set -gx HOME $_home
rm -rf $tmp_home

test_section "ebpf rootkit map probe"

set -l maps (aur_ebpf_rootkit_maps 2>/dev/null | string collect)
# Clean hosts have no campaign maps; probe must return an empty list, not error.
assert_not_match "ebpf probe errors" 'error|unknown command' "$maps"

test_finish "test-triage-persistence.fish"
exit $status
