# Tab-delimited findings store — tabs avoid breaking on commas in pacman log lines.
# Each line: category<TAB>item. Deduped on insert.

if not set -q AUR_FINDINGS_LIST_FILE
    set -g AUR_FINDINGS_LIST_FILE "$AUR_REPORTS_DIR/.scan-findings.list"
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
