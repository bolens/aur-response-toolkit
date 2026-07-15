#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "stolen-credentials inventory and --if-compromised"

set -l tmp_home (mktemp -d)
set -l _home $HOME
set -gx HOME $tmp_home
mkdir -p $HOME/.ssh $HOME/.config $HOME/.cache
printf 'PRIVATE\n' >$HOME/.ssh/id_ed25519
chmod 600 $HOME/.ssh/id_ed25519

# Keep persistence / env walks off the host (same pattern as run.fish integration).
set -gx AUR_HELPER_CACHE_ROOTS (mktemp -d)
set -gx AUR_PAMAC_BUILD_GLOBS '/nonexistent-pamac-*'
set -gx AUR_TEST_SYSTEMD_SYSTEM_DIR (mktemp -d)
set -gx AUR_TEST_SKIP_LD_PRELOAD 1
set -gx AUR_DEPS_SEARCH_PATHS $HOME/.cache
set -l _dev_root $AUR_DEV_ROOT
set -g AUR_DEV_ROOT $HOME/dev
mkdir -p $AUR_DEV_ROOT

set -l _reports $AUR_REPORTS_DIR
set -g AUR_REPORTS_DIR (mktemp -d)
set -gx AUR_STATE_FILE "$AUR_REPORTS_DIR/.scan-state"
set -gx AUR_FINDINGS_LIST_FILE "$AUR_REPORTS_DIR/.scan-findings.list"
aur_state_init

set -l script $AUR_SCRIPTS_DIR/audit/stolen-credentials.fish

# Without upstream compromise, credential inventory alone warns (exit 2).
begin
    fish $script --quiet
    assert_status "inventory-only exits warn" $AUR_EXIT_WARN
end

# With --if-compromised and no compromise mark, stay clean.
begin
    fish $script --quiet --if-compromised
    assert_status "if-compromised without mark is clean" $AUR_EXIT_CLEAN
end

aur_mark_compromised
begin
    fish $script --quiet --if-compromised
    assert_status "if-compromised with mark exits compromise" $AUR_EXIT_COMPROMISE
end

rm -rf $AUR_REPORTS_DIR $tmp_home $AUR_HELPER_CACHE_ROOTS $AUR_TEST_SYSTEMD_SYSTEM_DIR
set -g AUR_REPORTS_DIR $_reports
set -gx HOME $_home
set -g AUR_DEV_ROOT $_dev_root
set -e AUR_STATE_FILE
set -e AUR_FINDINGS_LIST_FILE
set -e AUR_HELPER_CACHE_ROOTS
set -e AUR_PAMAC_BUILD_GLOBS
set -e AUR_TEST_SYSTEMD_SYSTEM_DIR
set -e AUR_TEST_SKIP_LD_PRELOAD
set -e AUR_DEPS_SEARCH_PATHS

test_finish "test-stolen-credentials.fish"
exit $status
