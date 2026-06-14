# Tab-delimited findings store — tabs avoid breaking on commas in pacman log lines.
# Each line: category<TAB>item. Deduped on insert.

if not set -q AUR_FINDINGS_LIST_FILE
    set -g AUR_FINDINGS_LIST_FILE "$AUR_REPORTS_DIR/.scan-findings.list"
end

# Log a finding at the given severity, record it, and optionally bump a summary counter.
function aur_record_finding --argument-names severity category item message summary_key
    set -l tag (string upper $severity)
    set -l line $item
    test -n "$message"; and set line $message
    aur_log "  [$tag] $line"
    aur_finding_add $category $item
    if test -n "$summary_key"
        aur_summary_inc $summary_key 1
    end
end

function aur_finding_add --argument-names category item
    mkdir -p $AUR_REPORTS_DIR
    # Skip duplicate category+item pairs (steps may report the same path twice).
    if test -f $AUR_FINDINGS_LIST_FILE
        while read -l line
            set -l parts (string split \t -m1 -- $line)
            test (count $parts) -lt 2; and continue
            if test "$parts[1]" = "$category"; and test "$parts[2]" = "$item"
                return 0
            end
        end <$AUR_FINDINGS_LIST_FILE
    end
    printf '%s\t%s\n' "$category" "$item" >>$AUR_FINDINGS_LIST_FILE
end

function aur_finding_list --argument-names category
    if not test -f $AUR_FINDINGS_LIST_FILE
        return
    end
    while read -l line
        set -l parts (string split \t -m1 -- $line)
        test (count $parts) -lt 2; and continue
        if test "$parts[1]" = "$category"
            echo $parts[2]
        end
    end <$AUR_FINDINGS_LIST_FILE
end

function aur_finding_categories
    if not test -f $AUR_FINDINGS_LIST_FILE
        return
    end
    while read -l line
        set -l parts (string split \t -m1 -- $line)
        test (count $parts) -lt 2; and continue
        echo $parts[1]
    end <$AUR_FINDINGS_LIST_FILE | sort -u
end
