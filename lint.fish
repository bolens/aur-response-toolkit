#!/usr/bin/env fish

# Lint all Fish scripts in this repo.
# ShellCheck does not support fish (SC1071); use fishcheck instead.

set -g AUR_RESPONSE_DIR (dirname (status filename))

# Resolve fishcheck: PATH first, then common clone locations (ShellCheck does not support fish).
function _aur_resolve_fishcheck
    if set -l bin (command -sq fishcheck)
        echo $bin
        return 0
    end

    set -l candidates \
        "$HOME/.local/bin/fishcheck/fishcheck" \
        "$AUR_RESPONSE_DIR/tools/fishcheck/fishcheck"

    for candidate in $candidates
        if test -f $candidate
            echo $candidate
            return 0
        end
    end

    echo "fishcheck not found." >&2
    echo "Fisher lists mattmc3/fishcheck but does not expose the CLI; clone it:" >&2
    echo "  git clone https://github.com/mattmc3/fishcheck ~/.local/bin/fishcheck" >&2
    echo "  fish_add_path -g ~/.local/bin/fishcheck" >&2
    return 1
end

set -l scripts \
    $AUR_RESPONSE_DIR/run.fish \
    $AUR_RESPONSE_DIR/lint.fish \
    $AUR_RESPONSE_DIR/install.fish \
    $AUR_RESPONSE_DIR/bin/*.fish \
    $AUR_RESPONSE_DIR/scripts/_init.fish \
    $AUR_RESPONSE_DIR/scripts/*/*.fish \
    $AUR_RESPONSE_DIR/lib/*.fish \
    $AUR_RESPONSE_DIR/tests/run-all.fish \
    $AUR_RESPONSE_DIR/tests/support/*.fish \
    $AUR_RESPONSE_DIR/tests/unit/*/*.fish \
    $AUR_RESPONSE_DIR/tests/integration/*/*.fish
set -l fishcheck_bin
if not set fishcheck_bin (_aur_resolve_fishcheck)
    exit 1
end

set -l output ($fishcheck_bin $scripts 2>&1)
if test (count $output) -gt 0
    printf '%s\n' $output
end

if string match -qr 'FC\d{4} \((error|warning)\)' -- $output
    echo (count (string match -r 'FC\d{4}' -- $output))" fishcheck finding(s)."
    exit 1
end

echo "All Fish lint checks passed ("(count $scripts)" files, fishcheck)."
