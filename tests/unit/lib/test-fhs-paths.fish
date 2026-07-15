#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "list path helpers (FHS-style cache vs bundled)"

set -l _had_test false
set -l _saved
if set -q AUR_TEST_LIST_FILE
    set _saved $AUR_TEST_LIST_FILE
    set _had_test true
    set -e AUR_TEST_LIST_FILE
end

set -l xdg_lists (mktemp -d)
set -l cache $xdg_lists/atomic-arch-pkgs.txt
set -l _prev_file $AUR_ATOMIC_ARCH_LIST_FILE
set -l _prev_prev $AUR_ATOMIC_ARCH_LIST_PREVIOUS
set -g AUR_ATOMIC_ARCH_LIST_FILE $cache
set -g AUR_ATOMIC_ARCH_LIST_PREVIOUS $xdg_lists/atomic-arch-pkgs.previous.txt

assert_eq "missing FHS cache falls back to bundled" $AUR_ATOMIC_ARCH_LIST_BUNDLED (aur_atomic_arch_list_file_path)
assert_eq "write path stays FHS cache" $cache (aur_atomic_arch_list_write_path)

printf '%s\n' beef >$cache
assert_eq "populated FHS cache preferred for reads" $cache (aur_atomic_arch_list_file_path)

set -g AUR_ATOMIC_ARCH_LIST_FILE $_prev_file
set -g AUR_ATOMIC_ARCH_LIST_PREVIOUS $_prev_prev
rm -rf $xdg_lists
if test $_had_test = true
    set -gx AUR_TEST_LIST_FILE $_saved
end

test_section "unified list path helper"
assert_eq "chaos path helper" (aur_chaos_rat_list_file_path) (aur_list_file_path chaos-rat)
assert_eq "shai path helper" (aur_shai_hulud_list_file_path) (aur_list_file_path shai-hulud)
assert_eq "xeactor path helper" (aur_xeactor_list_file_path) (aur_list_file_path xeactor)

test_finish "test-fhs-paths.fish"
exit $status
