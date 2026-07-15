# Shared path classification for Git hooks — keep in sync with
# `.github/workflows/ci.yml` dorny/paths-filter `code:` globs.
#
# Usage:
#   source scripts/hooks/classify-paths.fish
#   aur_hook_classify_paths $paths...
#   # sets: AUR_HOOK_HAS_FISH AUR_HOOK_NEEDS_LINT AUR_HOOK_NEEDS_TEST AUR_HOOK_NEEDS_CODE

function aur_hook_path_is_code --argument-names path
    # Mirrors CI `code:` filter (fish + toolkit runtime + packaging + workflows).
    string match -q '*.fish' -- $path; and return 0
    string match -qr '^(lib|scripts|tests|data/lists|bin|systemd|packaging|completions)/' -- $path; and return 0
    string match -q VERSION -- $path; and return 0
    string match -q 'run.fish' -- $path; and return 0
    string match -q 'run.sh' -- $path; and return 0
    string match -q 'lint.fish' -- $path; and return 0
    string match -q 'install.fish' -- $path; and return 0
    string match -q 'config.fish.example' -- $path; and return 0
    string match -qr '^\.github/workflows/' -- $path; and return 0
    return 1
end

# Fish/lists/tests that exercise the suite locally (skip packaging-only / workflow-only).
function aur_hook_path_needs_test --argument-names path
    string match -q '*.fish' -- $path; and return 0
    string match -qr '^(lib|scripts|tests|data/lists|bin|completions)/' -- $path; and return 0
    string match -q 'run.fish' -- $path; and return 0
    string match -q 'install.fish' -- $path; and return 0
    string match -q 'lint.fish' -- $path; and return 0
    return 1
end

# Lint when Fish sources or entrypoints change (fishcheck scope).
function aur_hook_path_needs_lint --argument-names path
    string match -q '*.fish' -- $path; and return 0
    string match -qr '^(lib|scripts|tests|bin|completions)/' -- $path; and return 0
    string match -q 'run.fish' -- $path; and return 0
    string match -q 'install.fish' -- $path; and return 0
    string match -q 'lint.fish' -- $path; and return 0
    return 1
end

function aur_hook_classify_paths
    set -g AUR_HOOK_HAS_FISH false
    set -g AUR_HOOK_NEEDS_LINT false
    set -g AUR_HOOK_NEEDS_TEST false
    set -g AUR_HOOK_NEEDS_CODE false

    for path in $argv
        test -n "$path"; or continue
        if string match -q '*.fish' -- $path
            set -g AUR_HOOK_HAS_FISH true
        end
        if aur_hook_path_is_code $path
            set -g AUR_HOOK_NEEDS_CODE true
        end
        if aur_hook_path_needs_lint $path
            set -g AUR_HOOK_NEEDS_LINT true
        end
        if aur_hook_path_needs_test $path
            set -g AUR_HOOK_NEEDS_TEST true
        end
    end
end
