#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "rotate-hints SSH from audit findings"

set -l _state $AUR_STATE_FILE
set -l _reports $AUR_REPORTS_DIR
set -g AUR_REPORTS_DIR (mktemp -d)
set -gx AUR_STATE_FILE "$AUR_REPORTS_DIR/.scan-state"
aur_state_init
aur_finding_add audit_ssh_keys /home/test/.ssh/id_ed25519

set -l tmp_home (mktemp -d)
set -l hints (env AUR_STATE_FILE=$AUR_STATE_FILE HOME=$tmp_home fish (aur_script_path recovery/rotate-hints.fish) 2>&1 | string collect)
assert_match "ssh keygen hint" 'ssh-keygen -t ed25519 -f /home/test/.ssh/id_ed25519.new' "$hints"

test_section "aur_docker_config_registry_keys parses docker config"

set -l docker_cfg (test_fixture_path misc/docker-config.json)
set -l registries (aur_docker_config_registry_keys $docker_cfg | string collect)
assert_contains "docker registry index" 'https://index.docker.io/v1/' "$registries"
assert_contains "docker registry example" 'registry.example.com' "$registries"

rm -rf $AUR_REPORTS_DIR $tmp_home
set -g AUR_STATE_FILE $_state
set -g AUR_REPORTS_DIR $_reports

test_finish "test-rotate-hints.fish"
exit $status
