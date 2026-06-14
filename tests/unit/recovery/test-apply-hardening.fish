#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "apply-hardening dry-run"

set -l tmp_home (mktemp -d)
echo "# empty" >$tmp_home/.npmrc

set -l out (env HOME=$tmp_home fish (aur_script_path recovery/apply-hardening.fish) 2>&1 | string collect)
assert_match "dry-run mentions apply" DRY-RUN "$out"
assert_eq "npmrc unchanged" "# empty" (cat $tmp_home/.npmrc)

set -l out_apply (env HOME=$tmp_home fish (aur_script_path recovery/apply-hardening.fish) --apply 2>&1 | string collect)
set -l npmrc_after (cat $tmp_home/.npmrc | string collect)
assert_match "apply writes ignore-scripts" 'ignore-scripts=true' "$npmrc_after"
assert_match "applied message" APPLIED "$out_apply"

rm -rf $tmp_home

test_finish "test-apply-hardening.fish"
exit $status
