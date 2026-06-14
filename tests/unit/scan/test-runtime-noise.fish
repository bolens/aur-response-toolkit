#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "runtime proc toolkit noise filter"

assert_eq "pgrep self noise" true (aur_runtime_proc_is_toolkit_noise "12345 pgrep -af js-digest"; and echo true; or echo false)
assert_eq "ps fallback noise" true (aur_runtime_proc_is_toolkit_noise "12345 ps -eo pid=,args= js-digest"; and echo true; or echo false)
assert_eq "grep invocation noise" true (aur_runtime_proc_is_toolkit_noise "999 /usr/bin/grep js-digest"; and echo true; or echo false)
assert_eq "rg invocation noise" true (aur_runtime_proc_is_toolkit_noise "1284005 rg -F -- atomic-lockfile"; and echo true; or echo false)
assert_eq "scan script noise" true (aur_runtime_proc_is_toolkit_noise "42 fish scan-malware-artifacts.fish"; and echo true; or echo false)
assert_eq "toolkit path noise" true (aur_runtime_proc_is_toolkit_noise "77 /home/user/aur-response-toolkit/run.fish"; and echo true; or echo false)
assert_eq "real process kept" false (aur_runtime_proc_is_toolkit_noise "4242 node /tmp/js-digest/index.js"; and echo true; or echo false)
assert_eq "deps binary kept" false (aur_runtime_proc_is_toolkit_noise "1337 /var/lib/pacman/deps"; and echo true; or echo false)

test_finish "test-runtime-noise.fish"
exit $status
