#!/usr/bin/env fish

# Remove installed packages from the infected list (or explicit pkg args). --verify re-checks pacman -Qmq.

source (dirname (dirname (status filename)))/_init.fish

set -l pkgs
set -l dry_run false
set -l force false
set -l verify false
set -l list_type atomic-arch

for arg in $argv
    if string match -qr '^--list=' -- $arg
        set list_type (string replace -r '^--list=' '' -- $arg)
    end
end
set -l i 1
while test $i -le (count $argv)
    if test "$argv[$i]" = --list; and test $i -lt (count $argv)
        set list_type $argv[(math $i + 1)]
    end
    set i (math $i + 1)
end

for arg in $argv
    switch $arg
        case --dry-run
            set dry_run true
        case --force
            set force true
        case --verify
            set verify true
        case --help -h
            echo "Usage: recovery/remove-packages.fish [--list atomic-arch|chaos-rat|shai-hulud|xeactor] [--dry-run] [--force] [--verify] [pkg ...]"
            echo ""
            echo "Remove installed packages matching a threat list (or named pkgs)."
            echo "  --list atomic-arch   Atomic Arch package list (default)"
            echo "  --list chaos-rat     Chaos RAT / cracked-software list"
            echo "  --list shai-hulud    Mini Shai-Hulud AUR list"
            echo "  --list xeactor       xeactor AUR list (2018)"
            echo "  --verify          Re-check that no matching packages remain"
            exit 0
        case '--list=*' --list
            continue
        case '-*'
            echo "Unknown option: $arg" >&2
            echo "Try: fish recovery/remove-packages.fish --help" >&2
            exit $AUR_EXIT_INVALID
        case atomic-arch chaos-rat shai-hulud xeactor
            continue
        case '*'
            set -a pkgs $arg
    end
end

function aur_list_label_for_type --argument-names list_type
    switch $list_type
        case chaos-rat
            echo "Chaos RAT"
        case shai-hulud
            echo "Shai-Hulud"
        case xeactor
            echo "xeactor"
        case atomic-arch
            echo "Atomic Arch"
    end
end

function aur_installed_list_pkgs --argument-names list_type
    switch $list_type
        case chaos-rat
            aur_installed_chaos_rat_pkgs
        case shai-hulud
            aur_installed_shai_hulud_pkgs
        case xeactor
            aur_installed_xeactor_pkgs
        case atomic-arch
            aur_installed_atomic_arch_pkgs
        case '*'
            echo "ERROR: unknown list type '$list_type' (use atomic-arch, chaos-rat, shai-hulud, or xeactor)" >&2
            return 1
    end
end

if test $verify = true
    set -l remaining (aur_installed_list_pkgs $list_type)
    set -l label (aur_list_label_for_type $list_type)
    if test (count $remaining) -gt 0
        echo "VERIFY FAILED: "(count $remaining)" $label package(s) still installed:"
        for p in $remaining
            echo "  - $p"
        end
        if test $list_type = chaos-rat -o $list_type = shai-hulud -o $list_type = xeactor
            exit $AUR_EXIT_WARN
        end
        exit $AUR_EXIT_COMPROMISE
    end
    echo "VERIFY OK: no $label packages remain installed."
    exit $AUR_EXIT_CLEAN
end

if test (count $pkgs) -eq 0
    set -l list_file
    switch $list_type
        case chaos-rat
            set list_file (aur_chaos_rat_list_file_path)
        case shai-hulud
            set list_file (aur_shai_hulud_list_file_path)
        case xeactor
            set list_file (aur_xeactor_list_file_path)
        case atomic-arch
            set list_file (aur_atomic_arch_list_file_path)
        case '*'
            echo "ERROR: unknown list type '$list_type' (use atomic-arch, chaos-rat, shai-hulud, or xeactor)" >&2
            exit $AUR_EXIT_INVALID
    end
    if not test -f $list_file
        echo "ERROR: no packages specified and $list_file missing"
        if test $list_type = chaos-rat -o $list_type = shai-hulud -o $list_type = xeactor
            exit $AUR_EXIT_INSUFFICIENT
        end
        exit $AUR_EXIT_COMPROMISE
    end
    set pkgs (aur_installed_list_pkgs $list_type)
end

set -l label (aur_list_label_for_type $list_type)
if test (count $pkgs) -eq 0
    echo "No $label packages currently installed."
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
set -l remove_exit $status

if test $remove_exit -eq 0
    echo ""
    set -l remaining (aur_installed_list_pkgs $list_type)
    if test (count $remaining) -gt 0
        echo "WARN: some $label packages may remain: "(string join ', ' $remaining)
    else
        echo "Verified: no $label packages remain."
    end
    if test $list_type = atomic-arch
        echo ""
        echo "Next:"
        echo "  fish $AUR_RESPONSE_DIR/run.fish --audit --report"
        echo "  fish (aur_script_path recovery/rotate-hints.fish)"
        echo "  fish (aur_script_path recovery/scrub-history.fish) --all-shells"
    else if test $list_type = shai-hulud
        echo ""
        echo "Next: stop gh-token-monitor if present, then re-run the Shai-Hulud scan:"
        echo "  systemctl --user stop gh-token-monitor; systemctl --user disable gh-token-monitor"
        echo "  fish (aur_script_path check/shai-hulud-pkgs.fish) --shai-hulud"
    else if test $list_type = xeactor
        echo ""
        echo "Next: re-run the xeactor scan to confirm removal:"
        echo "  fish (aur_script_path check/xeactor-pkgs.fish) --xeactor"
    else
        echo ""
        echo "Next: re-run the Chaos RAT scan to confirm removal:"
        echo "  fish (aur_script_path check/chaos-rat-pkgs.fish) --chaos-rat"
    end
end

exit $remove_exit
