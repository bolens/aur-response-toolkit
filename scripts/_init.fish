# Shared bootstrap for scripts under scripts/{check,scan,audit,recovery}/.
if not set -q AUR_RESPONSE_DIR
    set -l here (dirname (status filename))
    while not test -f "$here/VERSION"; and test "$here" != /
        set here (dirname $here)
    end
    if not test -f "$here/VERSION"
        echo "error: cannot locate aur-response-toolkit root (missing VERSION)" >&2
        exit 1
    end
    set -g AUR_RESPONSE_DIR $here
end
source $AUR_RESPONSE_DIR/lib/common.fish
