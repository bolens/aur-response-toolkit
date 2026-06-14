#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "AUR helper cache directory resolution"

set -l cache_root (mktemp -d)
set -l pamac_root (mktemp -d)
mkdir -p $cache_root/paru-pkg
mkdir -p $pamac_root/pamac-pkg
cp (test_fixture_path pkgbuilds/pkgbuild.malicious) $cache_root/paru-pkg/PKGBUILD
cp (test_fixture_path pkgbuilds/pkgbuild.malicious) $pamac_root/pamac-pkg/PKGBUILD

set -l _roots $AUR_HELPER_CACHE_ROOTS
set -l _globs $AUR_PAMAC_BUILD_GLOBS
set -gx AUR_HELPER_CACHE_ROOTS $cache_root
set -gx AUR_PAMAC_BUILD_GLOBS $pamac_root

set -l paru_dirs (aur_aur_helper_pkg_cache_dirs paru-pkg | string collect)
assert_contains "paru-style cache dir found" "$cache_root/paru-pkg" "$paru_dirs"

set -l pamac_dirs (aur_aur_helper_pkg_cache_dirs pamac-pkg | string collect)
assert_contains "pamac-style cache dir found" "$pamac_root/pamac-pkg" "$pamac_dirs"

set -l hook_hits (aur_scan_aur_cache_hooks --pkg paru-pkg | string collect)
assert_contains "paru cache hook scan" "$cache_root/paru-pkg/PKGBUILD" "$hook_hits"

set -l pamac_hits (aur_scan_aur_cache_hooks --pkg pamac-pkg | string collect)
assert_contains "pamac cache hook scan" "$pamac_root/pamac-pkg/PKGBUILD" "$pamac_hits"

if set -q _roots[1]
    set -gx AUR_HELPER_CACHE_ROOTS $_roots
else
    set -e AUR_HELPER_CACHE_ROOTS
end
if set -q _globs[1]
    set -gx AUR_PAMAC_BUILD_GLOBS $_globs
else
    set -e AUR_PAMAC_BUILD_GLOBS
end
rm -rf $cache_root $pamac_root

test_section "pamac BuildDirectory auto-detection"

set -l pamac_cfg (mktemp)
set -l custom_build (mktemp -d)
mkdir -p $custom_build/pamac-build-$USER/evil-pkg
cp (test_fixture_path pkgbuilds/pkgbuild.malicious) $custom_build/pamac-build-$USER/evil-pkg/PKGBUILD
printf '%s\n' "BuildDirectory = $custom_build" >$pamac_cfg

set -l _globs $AUR_PAMAC_BUILD_GLOBS
set -e AUR_PAMAC_BUILD_GLOBS
set -l _saved_cfg /etc/pamac.conf
set -l _user_cfg "$HOME/.config/pamac/config"
mkdir -p (dirname $_user_cfg)
test -f $_user_cfg; and set -l _user_backup (mktemp); and cp $_user_cfg $_user_backup
cp $pamac_cfg $_user_cfg

set -l patterns (aur_pamac_build_glob_patterns | string collect)
assert_contains "custom BuildDirectory glob" "$custom_build/pamac-build-*" "$patterns"

set -l custom_hits (aur_scan_aur_cache_hooks --pkg evil-pkg | string collect)
assert_contains "custom pamac build dir hook scan" "$custom_build/pamac-build-$USER/evil-pkg/PKGBUILD" "$custom_hits"

rm -f $_user_cfg $pamac_cfg
test -n "$_user_backup"; and mv $_user_backup $_user_cfg
if set -q _globs[1]
    set -gx AUR_PAMAC_BUILD_GLOBS $_globs
else
    set -e AUR_PAMAC_BUILD_GLOBS
end
rm -rf $custom_build

test_section "pacman path overrides"

set -l jun10_epoch (date -d '2026-06-10 12:00:00' +%s)
set -l log_dir (mktemp -d)
echo '[2026-06-10T11:00:00-0600] [ALPM] installed bee (1-1)' >$log_dir/pacman.log
set -l _log $AUR_PACMAN_LOG_DIR
set -l _test_log $AUR_TEST_PACMAN_LOG_DIR
set -e AUR_TEST_PACMAN_LOG_DIR
set -gx AUR_PACMAN_LOG_DIR $log_dir
assert_eq "aur_pacman_log_dir override" $log_dir (aur_pacman_log_dir)
begin
    aur_pacman_logs_accessible
    assert_status "override log dir readable" 0
end
if set -q _log
    set -gx AUR_PACMAN_LOG_DIR $_log
else
    set -e AUR_PACMAN_LOG_DIR
end
if set -q _test_log
    set -gx AUR_TEST_PACMAN_LOG_DIR $_test_log
end
rm -rf $log_dir

set -l local_override (mktemp -d)
mkdir -p $local_override/foo-1-1
printf '%s\n' '%NAME%' foo '%INSTALLDATE%' $jun10_epoch >$local_override/foo-1-1/desc
set -l _local_override $AUR_PACMAN_LOCAL_DIR
set -e AUR_TEST_PACMAN_LOCAL_DIR
set -gx AUR_PACMAN_LOCAL_DIR $local_override
assert_eq "aur_pacman_local_dir override" $local_override (aur_pacman_local_dir)
assert_eq "epoch via local dir override" $jun10_epoch (aur_pkg_install_epoch foo)
if set -q _local_override
    set -gx AUR_PACMAN_LOCAL_DIR $_local_override
else
    set -e AUR_PACMAN_LOCAL_DIR
end
rm -rf $local_override

test_section "install epoch window matching (locale-independent)"

set -l jun10 (date -d '2026-06-10 12:00:00' +%s)
set -l jun1 (date -d '2026-06-01 12:00:00' +%s)

begin
    aur_epoch_in_atomic_arch_window $jun10
    assert_status "Jun 10 epoch in Atomic Arch window" 0
end
begin
    aur_epoch_in_atomic_arch_window $jun1
    assert_status "Jun 1 epoch outside Atomic Arch window" 1
end

set -l local_dir (mktemp -d)
mkdir -p $local_dir/window-pkg-1-1
printf '%s\n' '%NAME%' window-pkg '%INSTALLDATE%' $jun10 >$local_dir/window-pkg-1-1/desc

set -l _local $AUR_TEST_PACMAN_LOCAL_DIR
set -gx AUR_TEST_PACMAN_LOCAL_DIR $local_dir
begin
    aur_install_in_compromise_window window-pkg
    assert_status "epoch from desc classifies HIGH in window" 0
end
set -gx AUR_TEST_PACMAN_LOCAL_DIR $_local
rm -rf $local_dir

test_finish "test-aur-helper-cache.fish"
exit $status
