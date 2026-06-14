#!/usr/bin/env fish

source (dirname (dirname (status filename)))/lib/test-utils.fish

test_reset_counters
test_section "integration: scan-pacman-timeline with fixtures"

set -gx AUR_TEST_PACMAN_LOG_DIR (dirname (test_fixture_path pacman.log))
set -gx AUR_TEST_LIST_FILE (test_fixture_path infected-pkgs.txt)

set -l out_file (mktemp)
fish $AUR_SCRIPTS_DIR/scan-pacman-timeline.fish --local >$out_file 2>&1
set -l code $status
set -l out (cat $out_file)
rm -f $out_file
assert_eq "timeline exits 1 on hits" 1 $code
assert_match "beef hit in output" 'upgraded beef' "$out"
assert_not_match "bee not in timeline output" 'installed bee' "$out"

test_section "integration: scan-aur-window with fixtures"
set -gx AUR_TEST_FOREIGN_LIST (test_fixture_path foreign-pkgs.txt)

set -l window_out (mktemp)
fish $AUR_SCRIPTS_DIR/scan-aur-window.fish --local >$window_out 2>&1
set -l window_code $status
set -l window_text (cat $window_out)
rm -f $window_out

assert_eq "aur-window exits 1 on unknown foreign pkgs" 1 $window_code
assert_match "known beef flagged" '\[KNOWN\].*beef' "$window_text"
assert_match "unknown bee flagged" '\[NEW\?\].*bee' "$window_text"
assert_match "bracket log line printed" 'upgraded beef' "$window_text"

set -e AUR_TEST_FOREIGN_LIST

test_section "integration: remove-infected rejects unknown flags"
begin
    fish $AUR_SCRIPTS_DIR/remove-infected.fish --nope 2>/dev/null
    assert_status "unknown flag exits 2" 2
end

test_section "integration: rotate-hints docker registry parsing"
set -l docker_home (mktemp -d)
mkdir -p $docker_home/.docker
cp (test_fixture_path docker-config.json) $docker_home/.docker/config.json
set -l _home $HOME
set -l hints (env HOME=$docker_home fish $AUR_SCRIPTS_DIR/rotate-hints.fish 2>&1 | string collect)
assert_match "docker logout index" 'docker logout https://index.docker.io/v1/' "$hints"
assert_match "docker logout registry" 'docker logout registry.example.com' "$hints"

set -e AUR_TEST_PACMAN_LOG_DIR
set -e AUR_TEST_LIST_FILE
rm -rf $docker_home

test_finish "test-integration.fish"
exit $status
