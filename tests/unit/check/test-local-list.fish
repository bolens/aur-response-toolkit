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

test_section "list path prefers writable cache then bundled"

set -l _had_test_list_for_path false
set -l _saved_test_list_for_path
if set -q AUR_TEST_LIST_FILE
    set _saved_test_list_for_path $AUR_TEST_LIST_FILE
    set _had_test_list_for_path true
    set -e AUR_TEST_LIST_FILE
end
set -l _cache_file $AUR_ATOMIC_ARCH_LIST_FILE
set -l missing_cache /tmp/aur-test-missing-cache-$fish_pid/atomic-arch-pkgs.txt
set -g AUR_ATOMIC_ARCH_LIST_FILE $missing_cache
assert_eq "missing cache falls back to bundled" $AUR_ATOMIC_ARCH_LIST_BUNDLED (aur_atomic_arch_list_file_path)
mkdir -p (dirname $missing_cache)
printf '%s\n' beef >$missing_cache
assert_eq "existing cache preferred" $missing_cache (aur_atomic_arch_list_file_path)
assert_eq "write path is cache" $missing_cache (aur_atomic_arch_list_write_path)
rm -rf (dirname $missing_cache)
set -g AUR_ATOMIC_ARCH_LIST_FILE $_cache_file
if test $_had_test_list_for_path = true
    set -gx AUR_TEST_LIST_FILE $_saved_test_list_for_path
end

test_section "online fetch write path does not mutate bundled list"

set -l bundled (mktemp)
printf '%s\n' beef known-bad >$bundled
set -l bundled_sha (aur_sha256 $bundled)
test_set_list_file $bundled
set -l write_tmp (mktemp)
set -gx AUR_ATOMIC_ARCH_LIST_WRITE_FILE $write_tmp
# Force all remotes to fail so loader falls back to bundled into the write path only.
set -l _arch $AUR_LIST_URL_ARCH
set -l _cscs $AUR_LIST_URL_CSCS
set -gx AUR_LIST_URL_ARCH file:///nonexistent-aur-list-arch-$fish_pid
set -gx AUR_LIST_URL_CSCS file:///nonexistent-aur-list-cscs-$fish_pid
set -e AUR_LIST_URL_EXTRA
set -g AUR_OPT_quiet true
begin
    aur_load_atomic_arch_list false >/dev/null 2>&1
    assert_status "fallback fetch succeeds via bundled" 0
end
assert_eq "bundled list unchanged" $bundled_sha (aur_sha256 $bundled)
assert_eq "write path has beef" true (aur_grep -Fxq -- beef $write_tmp; and echo true; or echo false)
set -e AUR_ATOMIC_ARCH_LIST_WRITE_FILE
set -gx AUR_LIST_URL_ARCH $_arch
set -gx AUR_LIST_URL_CSCS $_cscs
rm -f $write_tmp $bundled

rm -f $stale_list
if test $_had_test_list = true
    set -gx AUR_TEST_LIST_FILE $_saved_list
else
    test_clear_list_file
end
set -g AUR_OPT_quiet $_quiet

test_finish "test-local-list.fish"
exit $status
