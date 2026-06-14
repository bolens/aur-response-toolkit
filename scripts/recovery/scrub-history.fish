#!/usr/bin/env fish

# Back up and redact shell history lines matching secret patterns (post-rotation cleanup).

source (dirname (dirname (status filename)))/_init.fish

set -g AUR_SCRUB_dry_run false
set -g AUR_SCRUB_all_shells false

for arg in $argv
    switch $arg
        case --dry-run
            set -g AUR_SCRUB_dry_run true
        case --all-shells
            set -g AUR_SCRUB_all_shells true
        case --help -h
            echo "Usage: recovery/scrub-history.fish [--dry-run] [--all-shells]"
            echo ""
            echo "Back up shell histories and redact lines matching secret patterns."
            echo "  --all-shells  Also scrub bash and zsh histories"
            exit 0
        case '-*'
            echo "Unknown option: $arg" >&2
            exit $AUR_EXIT_INVALID
    end
end

function scrub_one_file --argument-names history_file
    if not test -f $history_file
        echo "  Skip: $history_file (not found)"
        return 0
    end

    set -l backup "$history_file.bak."(date +%Y%m%d-%H%M%S)
    set -l scrubbed "$history_file.scrubbed"
    set -l total 0
    set -l redacted 0
    rm -f $scrubbed

    # Line-at-a-time: fish history is plain text; matched lines are dropped, not edited in place.
    while read -l line
        set total (math $total + 1)
        if string match -qir $AUR_HISTORY_SECRET_PATTERN -- $line
            set redacted (math $redacted + 1)
        else
            echo $line >>$scrubbed
        end
    end <$history_file

    echo "  $history_file — $total lines, $redacted matched"

    if test $redacted -eq 0
        rm -f $scrubbed
        return 0
    end

    if test "$AUR_SCRUB_dry_run" = true
        echo "    [--dry-run] Would backup to $backup and remove $redacted lines"
        rm -f $scrubbed
        return 0
    end

    cp $history_file $backup
    mv $scrubbed $history_file
    echo "    Backup: $backup"
    echo "    Removed: $redacted lines"
end

set -l files (aur_shell_history_paths --fish-only)
if test "$AUR_SCRUB_all_shells" = true
    set files (aur_shell_history_paths)
end

echo "Shell history scrub"
for f in $files
    scrub_one_file $f
end
echo "Done. Rotate any credentials that were in redacted lines first."
