#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "preflight environment notes"

set -l log_dir (mktemp -d)
set -l _log $AUR_PACMAN_LOG_DIR
set -l _test_log $AUR_TEST_PACMAN_LOG_DIR
set -e AUR_TEST_PACMAN_LOG_DIR
set -gx AUR_PACMAN_LOG_DIR $log_dir
set -gx AUR_HELPER_CACHE_ROOTS /tmp/aur-test-no-helper-cache-$fish_pid
set -e AUR_MAKEPKG_BUILD_DIRS

set -l out (mktemp)
begin
    aur_preflight_environment >$out 2>&1
end
set -l text (cat $out | string collect)
assert_match "warns unreadable pacman logs" 'pacman logs under' "$text"
assert_match "notes empty helper caches" 'No AUR helper build caches' "$text"

rm -f $out
if set -q _log
    set -gx AUR_PACMAN_LOG_DIR $_log
else
    set -e AUR_PACMAN_LOG_DIR
end
if set -q _test_log
    set -gx AUR_TEST_PACMAN_LOG_DIR $_test_log
end
set -e AUR_HELPER_CACHE_ROOTS
rm -rf $log_dir

test_section "pamac config assignment parser"

set -l cfg (mktemp)
printf '%s\n' 'BuildDirectory = /opt/pamac-builds' '# comment' >$cfg
assert_eq "reads BuildDirectory" '/opt/pamac-builds' (aur_read_config_assignment $cfg BuildDirectory)

test_finish "test-preflight.fish"
exit $status
