#!/usr/bin/env fish

set -l pkgs
set -l dry_run false
set -l force false

for arg in $argv
    switch $arg
        case --dry-run
            set dry_run true
        case --force
            set force true
        case --help -h
            echo "Usage: remove-infected.fish [--dry-run] [--force] [pkg ...]"
            echo ""
            echo "Remove installed packages matching infected-pkgs.txt (or named pkgs)."
            exit 0
        case '-*'
            echo "Unknown option: $arg" >&2
            echo "Try: fish remove-infected.fish --help" >&2
            exit 2
        case '*'
            set -a pkgs $arg
    end
end

set -g AUR_RESPONSE_DIR (dirname (dirname (status filename)))
source $AUR_RESPONSE_DIR/lib/common.fish

if test (count $pkgs) -eq 0
    if not test -f $AUR_LIST_FILE
        echo "ERROR: no packages specified and $AUR_LIST_FILE missing"
        exit 1
    end
    set -l installed_sorted (mktemp)
    set -l infected_sorted (mktemp)
    pacman -Qmq | sort >$installed_sorted
    sort -u $AUR_LIST_FILE >$infected_sorted
    set pkgs (comm -12 $installed_sorted $infected_sorted)
    rm -f $installed_sorted $infected_sorted
end

if test (count $pkgs) -eq 0
    echo "No infected packages currently installed."
    exit 0
end

echo "Packages to remove ("(count $pkgs)"):"
for p in $pkgs
    echo "  - $p"
end
echo ""
echo "Command: sudo pacman -Rns "(string join ' ' $pkgs)

if test $dry_run = true
    echo "[--dry-run] not executing"
    exit 0
end

if test $force = false
    read -l -P "Proceed? [y/N] " confirm
    if not string match -qi 'y*' -- $confirm
        echo "Aborted."
        exit 0
    end
end

sudo pacman -Rns $pkgs
set -l status $status

if test $status -eq 0
    echo ""
    echo "Removed. Next:"
    echo "  fish $AUR_RESPONSE_DIR/run.fish --audit --report"
    echo "  fish $AUR_SCRIPTS_DIR/rotate-hints.fish"
end

exit $status
