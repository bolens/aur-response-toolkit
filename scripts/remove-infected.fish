#!/usr/bin/env fish

# Remove installed packages from the infected list (or explicit pkg args). --verify re-checks pacman -Qmq.

set -g AUR_RESPONSE_DIR (dirname (dirname (status filename)))
source $AUR_RESPONSE_DIR/lib/common.fish

set -l pkgs
set -l dry_run false
set -l force false
set -l verify false

for arg in $argv
    switch $arg
        case --dry-run
            set dry_run true
        case --force
            set force true
        case --verify
            set verify true
        case --help -h
            echo "Usage: remove-infected.fish [--dry-run] [--force] [--verify] [pkg ...]"
            echo ""
            echo "Remove installed packages matching infected-pkgs.txt (or named pkgs)."
            echo "  --verify  Re-check that no infected packages remain (exits 1 if any found)"
            exit 0
        case '-*'
            echo "Unknown option: $arg" >&2
            echo "Try: fish remove-infected.fish --help" >&2
            exit $AUR_EXIT_INVALID
        case '*'
            set -a pkgs $arg
    end
end

function aur_installed_infected_pkgs
    if not test -f $AUR_LIST_FILE
        return 1
    end
    # Same comm -12 intersection as check-infected-pkgs.fish.
    set -l installed_sorted (mktemp)
    set -l infected_sorted (mktemp)
    pacman -Qmq | sort >$installed_sorted
    sort -u $AUR_LIST_FILE >$infected_sorted
    comm -12 $installed_sorted $infected_sorted
    rm -f $installed_sorted $infected_sorted
end

if test $verify = true
    # Used by recovery wizard after removal — independent of --dry-run flow.
    set -l remaining (aur_installed_infected_pkgs)
    if test (count $remaining) -gt 0
        echo "VERIFY FAILED: "(count $remaining)" infected package(s) still installed:"
        for p in $remaining
            echo "  - $p"
        end
        exit $AUR_EXIT_COMPROMISE
    end
    echo "VERIFY OK: no infected packages remain installed."
    exit $AUR_EXIT_CLEAN
end

if test (count $pkgs) -eq 0
    if not test -f $AUR_LIST_FILE
        echo "ERROR: no packages specified and $AUR_LIST_FILE missing"
        exit $AUR_EXIT_COMPROMISE
    end
    set pkgs (aur_installed_infected_pkgs)
end

if test (count $pkgs) -eq 0
    echo "No infected packages currently installed."
    exit $AUR_EXIT_CLEAN
end

echo "Packages to remove ("(count $pkgs)"):"
for p in $pkgs
    echo "  - $p"
end
echo ""
echo "Command: sudo pacman -Rns "(string join ' ' $pkgs)

if test $dry_run = true
    echo "[--dry-run] not executing"
    exit $AUR_EXIT_CLEAN
end

if test $force = false
    read -l -P "Proceed? [y/N] " confirm
    if not string match -qi 'y*' -- $confirm
        echo "Aborted."
        exit $AUR_EXIT_CLEAN
    end
end

sudo pacman -Rns $pkgs
set -l status $status

if test $status -eq 0
    echo ""
    set -l remaining (aur_installed_infected_pkgs)
    if test (count $remaining) -gt 0
        echo "WARN: some infected packages may remain: "(string join ', ' $remaining)
    else
        echo "Verified: no infected packages remain."
    end
    echo ""
    echo "Next:"
    echo "  fish $AUR_RESPONSE_DIR/run.fish --audit --report"
    echo "  fish $AUR_SCRIPTS_DIR/rotate-hints.fish"
    echo "  fish $AUR_SCRIPTS_DIR/scrub-history.fish --all-shells"
end

exit $status
