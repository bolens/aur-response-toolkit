#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters

test_section "aur_fetch_source_with_sha via curl file:// URL"

set -l community_path (test_fixture_path fetch/chaos-rat-community.txt)
set -l url "file://$community_path"
set -l fetch (aur_fetch_source_with_sha $url)
assert_status "curl file fetch succeeds" 0
set -l parts (string split '|' -- $fetch)
set -l tmp $parts[1]
set -l sha $parts[2]
test -f $tmp
assert_status "fetch writes temp copy" 0
set -l body (cat $tmp | string collect)
assert_match "community list includes minecraft-cracked" minecraft-cracked "$body"
assert_match "sha256 present" '.+' "$sha"
rm -f $tmp

test_section "aur_load_chaos_rat_list merges via curl file:// (no fetch fixtures)"

set -l _reports $AUR_REPORTS_DIR
set -l _findings $AUR_FINDINGS_LIST_FILE
set -l _arch_url $AUR_CHAOS_RAT_URL_ARCH
set -l _community_url $AUR_CHAOS_RAT_URL_COMMUNITY
set -l _arch_fixture $AUR_TEST_CHAOS_RAT_ARCH_FILE
set -l _community_fixture $AUR_TEST_CHAOS_RAT_COMMUNITY_FILE

set -g AUR_REPORTS_DIR (mktemp -d)
set -gx AUR_FINDINGS_LIST_FILE "$AUR_REPORTS_DIR/.scan-findings.list"
aur_state_init
set -l out_list (mktemp)
set -l out_prev (mktemp)
set -gx AUR_TEST_CHAOS_RAT_LIST_FILE $out_list
set -gx AUR_CHAOS_RAT_LIST_PREVIOUS $out_prev
set -e AUR_TEST_CHAOS_RAT_ARCH_FILE
set -e AUR_TEST_CHAOS_RAT_COMMUNITY_FILE
set -g AUR_CHAOS_RAT_URL_ARCH "file://"(test_fixture_path fetch/chaos-rat-arch-advisory.html)
set -g AUR_CHAOS_RAT_URL_COMMUNITY "file://"(test_fixture_path fetch/chaos-rat-community.txt)
set -g AUR_OPT_quiet true

set -l merged (aur_load_chaos_rat_list false | string collect)
assert_status "file merge load succeeds" 0
assert_match "official pkg from advisory html" librewolf-fix-bin "$merged"
assert_match "community pkg from txt" minecraft-cracked "$merged"
set -l sha_findings (aur_finding_list list_source_sha256 | string collect)
assert_match "file arch sha recorded" 'chaos-arch-ml=[a-f0-9]{64}' "$sha_findings"
assert_match "file community sha recorded" 'chaos-community=[a-f0-9]{64}' "$sha_findings"

rm -f $out_list $out_prev
set -g AUR_CHAOS_RAT_URL_ARCH $_arch_url
set -g AUR_CHAOS_RAT_URL_COMMUNITY $_community_url
if set -q _arch_fixture[1]
    set -gx AUR_TEST_CHAOS_RAT_ARCH_FILE $_arch_fixture
end
if set -q _community_fixture[1]
    set -gx AUR_TEST_CHAOS_RAT_COMMUNITY_FILE $_community_fixture
end
set -g AUR_REPORTS_DIR $_reports
if set -q _findings[1]
    set -gx AUR_FINDINGS_LIST_FILE $_findings
else
    set -e AUR_FINDINGS_LIST_FILE
end

test_finish "test-http-fetch.fish"
exit $status
