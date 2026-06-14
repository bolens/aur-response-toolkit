#!/usr/bin/env fish

set -g AUR_RESPONSE_DIR (dirname (status filename))
source $AUR_RESPONSE_DIR/lib/common.fish

set -l history_file $HOME/.local/share/fish/fish_history
set -l dry_run false

for arg in $argv
    switch $arg
        case --dry-run
            set dry_run true
        case --help -h
            echo "Usage: scrub-history.fish [--dry-run]"
            echo "Backs up fish history and redacts lines matching secret patterns."
            exit 0
    end
end

if not test -f $history_file
    echo "No fish history at $history_file"
    exit 0
end

set -l backup "$history_file.bak."(date +%Y%m%d-%H%M%S)
set -l pattern 'password|token|ghp_|github_pat|api[_-]?key|secret|BEGIN (RSA|OPENSSH)|CLOUDFLARE|AWS_|docker login|npm login|hash-password|changepassword'

set -l total 0
set -l redacted 0

while read -l line
    set total (math $total + 1)
    if string match -qir $pattern -- $line
        set redacted (math $redacted + 1)
    else
        echo $line
    end
end <$history_file >$history_file.scrubbed

echo "Fish history scrub"
echo "  Source:  $history_file"
echo "  Lines:   $total total, $redacted matched for redaction"

if test $redacted -eq 0
    rm -f $history_file.scrubbed
    echo "  Nothing to scrub."
    exit 0
end

if test $dry_run = true
    echo "  [--dry-run] Would backup to $backup and remove $redacted lines"
    rm -f $history_file.scrubbed
    exit 0
end

cp $history_file $backup
mv $history_file.scrubbed $history_file
echo "  Backup:  $backup"
echo "  Removed: $redacted lines"
echo "Done. Rotate any credentials that were in those lines first."
