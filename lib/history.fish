# Shell history helpers — correlate risky AUR helper usage with compromise-window activity.

function aur_require_pacman_logs
    if aur_pacman_logs_accessible
        return 0
    end
    set -l log_dir (aur_pacman_log_dir)
    aur_insufficient_data "no readable pacman logs under $log_dir/pacman.log*"
    aur_log_insufficient_help
    exit $AUR_EXIT_INSUFFICIENT
end

# Shell history file paths. Default: fish + bash + zsh. --fish-only: fish history only.
function aur_shell_history_paths
    if contains -- --fish-only $argv
        echo $HOME/.local/share/fish/fish_history
        return
    end
    echo $HOME/.bash_history $HOME/.zsh_history $HOME/.local/share/fish/fish_history
end

# Match AUR helper invocations that skipped PKGBUILD review.
function aur_history_line_has_noconfirm_aur --argument-names line
    set -l h $AUR_HISTORY_HELPERS
    set -l pat (string join '' '(^|[\s"'\''-])(' $h ')(\s|$).*(--noconfirm|--no-confirm|--batch|--noedit)|(--noconfirm|--no-confirm|--batch|--noedit).*(\s|^)(' $h ')(\s|$)')
    string match -qir $pat -- $line
end

function aur_history_has_noconfirm_aur --argument-names path
    if not test -f $path
        return 1
    end
    while read -l line
        aur_history_line_has_noconfirm_aur $line; and return 0
    end <$path
    return 1
end

# True when any foreign package was installed/upgraded during the compromise window.
function aur_foreign_activity_in_window
    if not aur_pacman_logs_accessible
        return 1
    end
    set -l events (mktemp)
    set -l foreign_sorted (mktemp)
    aur_collect_window_alpm_events_all $events
    aur_foreign_package_names | sort >$foreign_sorted
    set -l raw (aur_foreign_packages_in_window $events $foreign_sorted | string collect)
    rm -f $events $foreign_sorted
    test (aur_safe_count "$raw") -gt 0
end

# Only flag --noconfirm when it correlates with actual AUR activity in the window.
function aur_history_noconfirm_during_window --argument-names path
    if not aur_foreign_activity_in_window
        return 1
    end
    aur_history_has_noconfirm_aur $path
end

function aur_history_secret_hits --argument-names path
    if not test -f $path
        echo 0
        return
    end
    set -l count 0
    while read -l line
        if string match -qir $AUR_HISTORY_SECRET_PATTERN -- $line
            set count (math $count + 1)
        end
    end <$path
    echo $count
end
