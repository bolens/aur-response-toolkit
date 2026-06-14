#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "integration: scan/atomic-arch-timeline with fixtures"

set -gx AUR_TEST_PACMAN_LOG_DIR (dirname (test_fixture_path logs/pacman.log))
set -gx AUR_TEST_LIST_FILE (test_fixture_path lists/atomic-arch-pkgs.txt)

set -l out_file (mktemp)
fish (aur_script_path scan/atomic-arch-timeline.fish) --local >$out_file 2>&1
set -l code $status
set -l out (cat $out_file)
rm -f $out_file
assert_eq "timeline exits 1 on hits" 1 $code
assert_match "beef hit in output" 'upgraded beef' "$out"
assert_match "beef repeat flagged" '\[REPEAT\].*beef' "$out"
assert_match "repeat explains takedown" 'post-takedown' "$out"
assert_not_match "bee not in timeline output" 'installed bee' "$out"

test_section "integration: scan/atomic-arch-timeline --all-time"
set -l alltime_dir (mktemp -d)
echo '[2026-02-01T08:00:00-0600] [ALPM] installed known-bad (1-1)' >$alltime_dir/pacman.log
set -gx AUR_TEST_PACMAN_LOG_DIR $alltime_dir
set -l alltime_out (mktemp)
fish (aur_script_path scan/atomic-arch-timeline.fish) --local --all-time >$alltime_out 2>&1
set -l alltime_code $status
set -l alltime_text (cat $alltime_out)
assert_eq "all-time timeline compromise" $AUR_EXIT_COMPROMISE $alltime_code
assert_match "all-time finds pre-window known-bad" 'known-bad' "$alltime_text"
rm -f $alltime_out
rm -rf $alltime_dir
set -gx AUR_TEST_PACMAN_LOG_DIR (dirname (test_fixture_path logs/pacman.log))

test_section "integration: scan-aur-window with fixtures"
set -gx AUR_TEST_FOREIGN_LIST (test_fixture_path lists/foreign-pkgs.txt)

set -l window_out (mktemp)
fish (aur_script_path scan/aur-window.fish) --local >$window_out 2>&1
set -l window_code $status
set -l window_text (cat $window_out)
rm -f $window_out

assert_eq "aur-window exits 2 on benign unknown foreign pkgs" $AUR_EXIT_WARN $window_code
assert_match "benign severity in output" 'severity: review \(benign triage\)' "$window_text"
assert_match "known beef flagged" '\[KNOWN\].*beef' "$window_text"
assert_match "beef repeat in window scan" 'repeat: 2 updates' "$window_text"
assert_match "unknown bee flagged" '\[NEW\?\].*bee' "$window_text"
assert_match "bracket log line printed" 'upgraded beef' "$window_text"

set -e AUR_TEST_FOREIGN_LIST

test_section "integration: remove-packages rejects unknown flags"
begin
    fish (aur_script_path recovery/remove-packages.fish) --nope 2>/dev/null
    assert_status "unknown flag exits 4" $AUR_EXIT_INVALID
end

test_section "integration: rotate-hints docker registry parsing"
set -l docker_home (mktemp -d)
mkdir -p $docker_home/.docker
cp (test_fixture_path misc/docker-config.json) $docker_home/.docker/config.json
set -l _home $HOME
set -l hints (env HOME=$docker_home fish (aur_script_path recovery/rotate-hints.fish) 2>&1 | string collect)
assert_match "docker logout index" 'docker logout https://index.docker.io/v1/' "$hints"
assert_match "docker logout registry" 'docker logout registry.example.com' "$hints"

set -e AUR_TEST_PACMAN_LOG_DIR
set -e AUR_TEST_LIST_FILE
rm -rf $docker_home

test_finish "test-integration.fish"
exit $status
