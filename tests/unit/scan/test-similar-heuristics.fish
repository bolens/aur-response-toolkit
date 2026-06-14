#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters

test_section "similar heuristics noise filter"
assert_eq "maintainer base64 is noise" true \
    (aur_similar_heuristics_line_is_noise "# Maintainer: noraj <printf %s 'foo'|base64 -d>"; and echo true; or echo false)
assert_eq "npm hook is not noise" false \
    (aur_similar_heuristics_line_is_noise "  npm install atomic-lockfile"; and echo true; or echo false)

test_section aur_file_has_similar_heuristics
set -l malicious (test_fixture_path pkgbuilds/pkgbuild.malicious)
set -l clean (test_fixture_path pkgbuilds/pkgbuild.clean)
begin
    aur_file_has_similar_heuristics $malicious
    assert_status "malicious PKGBUILD matches heuristics" 0
end
begin
    aur_file_has_similar_heuristics $clean
    assert_status "clean PKGBUILD no heuristic match" 1
end

test_section aur_foreign_installed_not_on_list
set -l list (test_fixture_path lists/atomic-arch-pkgs.txt)
set -gx AUR_TEST_INSTALLED_LIST (test_fixture_path lists/foreign-pkgs.txt)
set -l not_listed (aur_foreign_installed_not_on_list $list | string collect)
assert_contains "bee not on list" bee "$not_listed"
assert_not_match "beef on list excluded" '^beef$' "$not_listed"
set -e AUR_TEST_INSTALLED_LIST

test_section aur_pkg_similar_heuristics_files
set -l _home $HOME
set -l tmp_home (mktemp -d)
set -gx HOME $tmp_home
mkdir -p $HOME/.cache/paru/clone/evil-pkg
cp (test_fixture_path pkgbuilds/pkgbuild.malicious) $HOME/.cache/paru/clone/evil-pkg/PKGBUILD
set -l files (aur_pkg_similar_heuristics_files evil-pkg | string collect)
assert_contains "cache PKGBUILD flagged" \
    "$HOME/.cache/paru/clone/evil-pkg/PKGBUILD" "$files"
set -gx HOME $_home
rm -rf $tmp_home

test_section "scan-similar-heuristics flags non-listed hook"
set -l _home $HOME
set -l tmp_home (mktemp -d)
set -gx HOME $tmp_home
mkdir -p $HOME/.cache/paru/clone/evil-pkg
cp (test_fixture_path pkgbuilds/pkgbuild.malicious) $HOME/.cache/paru/clone/evil-pkg/PKGBUILD
set -gx AUR_TEST_INSTALLED_LIST (mktemp)
echo evil-pkg >$AUR_TEST_INSTALLED_LIST
set -l test_list (mktemp)
printf '%s\n' beef known-bad >$test_list
set -gx AUR_TEST_LIST_FILE $test_list
set -l out (mktemp)
fish (aur_script_path scan/similar-heuristics.fish) --local --no-chain >$out 2>&1
assert_eq "non-listed hook exits compromise" $AUR_EXIT_COMPROMISE $status
set -l body (cat $out | string collect)
assert_match "evil-pkg critical" 'CRITICAL.*evil-pkg' "$body"
set -gx HOME $_home
set -e AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_LIST_FILE
rm -f $out $AUR_TEST_INSTALLED_LIST $test_list
rm -rf $tmp_home

test_section "maintainer base64 heuristic is review-only"
set -l _home $HOME
set -l tmp_home (mktemp -d)
set -gx HOME $tmp_home
mkdir -p $HOME/.cache/paru/clone/nessus-like
printf '%s\n' \
    '# Maintainer: noraj <printf %s '"'"'YWxleEBleGFtcGxlLmNvbQ=='"'"'|base64 -d>' \
    'pkgver=1' >$HOME/.cache/paru/clone/nessus-like/PKGBUILD
set -gx AUR_TEST_INSTALLED_LIST (mktemp)
echo nessus-like >$AUR_TEST_INSTALLED_LIST
set -l test_list2 (mktemp)
printf '%s\n' beef known-bad >$test_list2
set -gx AUR_TEST_LIST_FILE $test_list2
set -l out2 (mktemp)
fish (aur_script_path scan/similar-heuristics.fish) --local --no-chain >$out2 2>&1
assert_eq "maintainer base64 not compromise" $AUR_EXIT_CLEAN $status
set -e AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_LIST_FILE
set -gx HOME $_home
rm -f $out2 $AUR_TEST_INSTALLED_LIST
rm -rf $tmp_home

test_finish "test-similar-heuristics.fish"
exit $status
