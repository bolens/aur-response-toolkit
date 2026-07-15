#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish
source $AUR_RESPONSE_DIR/scripts/hooks/classify-paths.fish

test_reset_counters
test_section "hook path filters match CI code intent"

begin
    aur_hook_path_is_code lib/cli.fish
    assert_status "fish is code" 0
end
begin
    aur_hook_path_is_code README.md
    assert_status "md is not code" 1
end
begin
    aur_hook_path_is_code .github/workflows/ci.yml
    assert_status "workflow is code" 0
end
begin
    aur_hook_path_is_code packaging/arch/PKGBUILD
    assert_status "packaging is code" 0
end
begin
    aur_hook_path_needs_test data/lists/atomic-arch-pkgs.txt
    assert_status "lists need test" 0
end
begin
    aur_hook_path_needs_test packaging/arch/PKGBUILD
    assert_status "packaging skips local test" 1
end
begin
    aur_hook_path_needs_test .github/workflows/ci.yml
    assert_status "workflow skips local test" 1
end
begin
    aur_hook_path_needs_lint packaging/arch/PKGBUILD
    assert_status "packaging skips lint" 1
end
begin
    aur_hook_path_needs_lint run.fish
    assert_status "fish needs lint" 0
end

aur_hook_classify_paths README.md CONTRIBUTING.md
assert_eq "docs-only code" false $AUR_HOOK_NEEDS_CODE
assert_eq "docs-only lint" false $AUR_HOOK_NEEDS_LINT
assert_eq "docs-only test" false $AUR_HOOK_NEEDS_TEST

aur_hook_classify_paths lib/cli.fish packaging/arch/PKGBUILD
assert_eq "mixed has fish" true $AUR_HOOK_HAS_FISH
assert_eq "mixed needs code" true $AUR_HOOK_NEEDS_CODE
assert_eq "mixed needs lint" true $AUR_HOOK_NEEDS_LINT
assert_eq "mixed needs test" true $AUR_HOOK_NEEDS_TEST

aur_hook_classify_paths packaging/arch/PKGBUILD .github/workflows/ci.yml
assert_eq "packaging-only code" true $AUR_HOOK_NEEDS_CODE
assert_eq "packaging-only lint" false $AUR_HOOK_NEEDS_LINT
assert_eq "packaging-only test" false $AUR_HOOK_NEEDS_TEST

test_finish "test-hook-path-filters.fish"
exit $status
