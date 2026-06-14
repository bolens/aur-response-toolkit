#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters

function test_setup_clean_run_env
    set -l log_dir (mktemp -d)
    echo '[2026-02-01T08:00:00-0600] [ALPM] upgraded clean-aur (1-1 -> 2-1)' >$log_dir/pacman.log
    set -gx AUR_TEST_PACMAN_LOG_DIR $log_dir

    set -l foreign (mktemp)
    echo clean-aur >$foreign
    set -gx AUR_TEST_FOREIGN_LIST $foreign

    set -l installed (mktemp)
    echo clean-aur >$installed
    set -gx AUR_TEST_INSTALLED_LIST $installed

    set -l pkg_info (mktemp)
    echo 'clean-aur|Mon 02 Feb 2026 12:00:00|Explicitly installed' >$pkg_info
    set -gx AUR_TEST_PKG_INFO $pkg_info

    set -gx AUR_TEST_LIST_FILE (test_fixture_path lists/atomic-arch-pkgs.txt)
    set -gx AUR_TEST_CHAOS_RAT_LIST_FILE (test_fixture_path lists/chaos-rat-pkgs.txt)
    set -gx AUR_TEST_SHAI_HULUD_LIST_FILE (test_fixture_path lists/shai-hulud-pkgs.txt)
    set -gx AUR_TEST_XEACTOR_LIST_FILE (test_fixture_path lists/xeactor-pkgs.txt)

    # Isolate AUR helper cache scans from the host system (malware-artifacts / similar-heuristics).
    set -gx AUR_HELPER_CACHE_ROOTS (mktemp -d)
    set -gx AUR_PAMAC_BUILD_GLOBS '/nonexistent-pamac-*'

    # Fresh scan state so prior suites cannot leave compromised=1 on disk.
    set -gx AUR_TEST_SAVED_STATE_FILE $AUR_STATE_FILE
    set -gx AUR_STATE_FILE (mktemp)
    aur_state_init
end

function test_teardown_run_env
    if set -q AUR_TEST_PACMAN_LOG_DIR
        rm -rf $AUR_TEST_PACMAN_LOG_DIR
        set -e AUR_TEST_PACMAN_LOG_DIR
    end
    if set -q AUR_TEST_FOREIGN_LIST
        rm -f $AUR_TEST_FOREIGN_LIST
        set -e AUR_TEST_FOREIGN_LIST
    end
    if set -q AUR_TEST_INSTALLED_LIST
        rm -f $AUR_TEST_INSTALLED_LIST
        set -e AUR_TEST_INSTALLED_LIST
    end
    if set -q AUR_TEST_PKG_INFO
        rm -f $AUR_TEST_PKG_INFO
        set -e AUR_TEST_PKG_INFO
    end
    set -e AUR_TEST_LIST_FILE
    set -e AUR_TEST_CHAOS_RAT_LIST_FILE
    set -e AUR_TEST_SHAI_HULUD_LIST_FILE
    set -e AUR_TEST_XEACTOR_LIST_FILE
    if set -q AUR_HELPER_CACHE_ROOTS
        rm -rf $AUR_HELPER_CACHE_ROOTS
        set -e AUR_HELPER_CACHE_ROOTS
    end
    set -e AUR_PAMAC_BUILD_GLOBS
    if set -q AUR_STATE_FILE
        rm -f $AUR_STATE_FILE
    end
    if set -q AUR_TEST_SAVED_STATE_FILE
        set -gx AUR_STATE_FILE $AUR_TEST_SAVED_STATE_FILE
        set -e AUR_TEST_SAVED_STATE_FILE
    else
        set -e AUR_STATE_FILE
    end
end

test_section "run.fish orchestrates optional campaign steps (clean)"

test_setup_clean_run_env
set -l run_out (mktemp)
fish $AUR_RESPONSE_DIR/run.fish --local --skip-pkg-check --fail-on none \
    --chaos-rat --shai-hulud --xeactor >$run_out 2>&1
set -l run_code $status
set -l run_text (cat $run_out | string collect)
assert_eq "clean optional-campaign run exits 0" $AUR_EXIT_CLEAN $run_code
assert_match "runs chaos rat pkg scan" 'Step 1b' "$run_text"
assert_match "runs shai hulud pkg scan" 'Step 1c' "$run_text"
assert_match "runs xeactor pkg scan" 'Step 1d' "$run_text"
assert_match "runs chaos rat timeline" 'Step 3b' "$run_text"
assert_match "runs shai hulud timeline" 'Step 3c' "$run_text"
assert_match "runs xeactor timeline" 'Step 3d' "$run_text"
rm -f $run_out
test_teardown_run_env

test_section "run.fish exits warn when optional campaigns hit installed pkgs"

set -l log_dir (mktemp -d)
echo '[2026-02-01T08:00:00-0600] [ALPM] upgraded clean-aur (1-1 -> 2-1)' >$log_dir/pacman.log
set -gx AUR_TEST_PACMAN_LOG_DIR $log_dir
set -gx AUR_TEST_FOREIGN_LIST (mktemp)
echo clean-aur >$AUR_TEST_FOREIGN_LIST
set -gx AUR_TEST_INSTALLED_LIST (mktemp)
printf '%s\n' chaos-pkg-a shai-pkg-a legacy-pkg-a >$AUR_TEST_INSTALLED_LIST
set -gx AUR_TEST_PKG_INFO (mktemp)
printf '%s\n' \
    'chaos-pkg-a|Mon 17 Jul 2025 20:00:00|Explicitly installed' \
    'shai-pkg-a|Sat 17 May 2026 20:00:00|Explicitly installed' \
    'legacy-pkg-a|Thu 07 Jun 2018 20:00:00|Explicitly installed' >$AUR_TEST_PKG_INFO
set -gx AUR_TEST_LIST_FILE (test_fixture_path lists/atomic-arch-pkgs.txt)
set -gx AUR_TEST_CHAOS_RAT_LIST_FILE (test_fixture_path lists/chaos-rat-pkgs.txt)
set -gx AUR_TEST_SHAI_HULUD_LIST_FILE (test_fixture_path lists/shai-hulud-pkgs.txt)
set -gx AUR_TEST_XEACTOR_LIST_FILE (test_fixture_path lists/xeactor-pkgs.txt)
set -gx AUR_HELPER_CACHE_ROOTS (mktemp -d)
set -gx AUR_PAMAC_BUILD_GLOBS '/nonexistent-pamac-*'
set -gx AUR_TEST_SAVED_STATE_FILE $AUR_STATE_FILE
set -gx AUR_STATE_FILE (mktemp)
aur_state_init

set -l hit_out (mktemp)
set -l hit_json (mktemp)
fish $AUR_RESPONSE_DIR/run.fish --local --skip-pkg-check --fail-on all --json --quiet \
    --chaos-rat --shai-hulud --xeactor >$hit_json 2>$hit_out
set -l hit_code $status
set -l hit_text (cat $hit_out | string collect)
assert_eq "optional campaign hits exit warn" $AUR_EXIT_WARN $hit_code
if command -q jq
    assert_eq "json chaos_rat_installed" 1 (jq -r .chaos_rat_installed $hit_json)
    assert_eq "json shai_hulud_installed" 1 (jq -r .shai_hulud_installed $hit_json)
    assert_eq "json xeactor_installed" 1 (jq -r .xeactor_installed $hit_json)
    assert_eq "json exit_code warn" $AUR_EXIT_WARN (jq -r .exit_code $hit_json)
else
    assert_match "result reports warnings without jq" 'WARNINGS ONLY' "$hit_text"
end
rm -f $hit_out $hit_json
test_teardown_run_env

test_finish "test-run-optional-campaigns.fish"
exit $status
