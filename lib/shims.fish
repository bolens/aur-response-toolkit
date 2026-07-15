# Tool shims (grep/find/curl/sha256/hostname) for portable CI hosts.

function aur_grep
    if not command -q rg
        command grep $argv
        return $status
    end

    set -l rg_flags
    set -l args $argv
    set -l skip_next false

    while test (count $args) -gt 0
        set -l arg $args[1]
        if test "$skip_next" = true
            set skip_next false
            set args $args[2..-1]
            continue
        end

        switch $arg
            case --
                set args $args[2..-1]
                break
            case -F --fixed-strings
                set -a rg_flags -F
                set args $args[2..-1]
            case -x --line-regexp
                set -a rg_flags -x
                set args $args[2..-1]
            case -q --quiet --silent
                set -a rg_flags -q
                set args $args[2..-1]
            case -o --only-matching
                set -a rg_flags -o
                set args $args[2..-1]
            case -E --extended-regexp
                set args $args[2..-1]
            case -m1
                set -a rg_flags -m 1
                set args $args[2..-1]
            case '-m*'
                set -a rg_flags -m (string sub -s 3 -- $arg)
                set args $args[2..-1]
            case -m
                set -a rg_flags -m $args[2]
                set skip_next true
                set args $args[2..-1]
            case '-*'
                # Flag we do not translate — delegate to grep unchanged.
                command grep $argv
                return $status
            case '*'
                break
        end
    end

    command rg $rg_flags -- $args
end

# Find compatibility shim: prefer fd when flags are translatable; otherwise GNU find.
# Callers use find-style flags; unknown options fall through to find unchanged.
function aur_find
    if not command -q fd
        command find $argv
        return $status
    end

    set -l args $argv
    set -l fd_flags -H -I
    set -l paths
    set -l use_find false
    set -l skip_next false

    while test (count $args) -gt 0
        set -l arg $args[1]

        if test "$skip_next" = true
            set skip_next false
            set args $args[2..-1]
            continue
        end

        switch $arg
            case '(' ')'
                set use_find true
            case -o
                set use_find true
            case -mtime -perm -size
                set use_find true
            case -maxdepth
                if test (count $args) -lt 2
                    set use_find true
                else
                    set -a fd_flags --max-depth $args[2]
                    set skip_next true
                end
            case -type
                if test (count $args) -lt 2
                    set use_find true
                else
                    switch $args[2]
                        case f
                            set -a fd_flags -t f
                        case d
                            set -a fd_flags -t d
                        case '*'
                            set use_find true
                    end
                    set skip_next true
                end
            case -name
                if test (count $args) -lt 2
                    set use_find true
                else
                    set -a fd_flags -g $args[2]
                    set skip_next true
                end
            case --
                set args $args[2..-1]
                break
            case '-*'
                set use_find true
            case '*'
                set -a paths $arg
        end

        set args $args[2..-1]
    end

    if test $use_find = true
        command find $argv
        return $status
    end

    if test (count $paths) -eq 0
        set paths .
    end

    set -l seen
    for p in $paths
        set -l hits
        if string match -q '.' -- $p
            set hits (command fd -H -I $fd_flags . 2>/dev/null)
        else if string match -qr '^/' -- $p
            set hits (command fd -H -I $fd_flags . -- $p 2>/dev/null)
        else
            set hits (command fd -H -I $fd_flags -- $p 2>/dev/null)
        end
        for line in $hits
            set line (string trim -r -c / -- $line)
            contains -- $line $seen; and continue
            set -a seen $line
            echo $line
        end
    end
end

# Curl compatibility shim: prefer curlie when available; fall back to curl.
# file:// URLs always use curl — curlie rejects them; relative paths are absolutized.
function aur_curl
    set -l args $argv
    for i in (seq (count $args))
        if string match -qr '^file://' -- $args[$i]
            set -l path (string replace -r '^file://' '' -- $args[$i])
            while string match -q '//'* -- $path
                set path (string sub -s 2 -- $path)
            end
            if test -n "$path" -a "$path" != /
                if not string match -qr '^/' -- $path
                    set path (aur_realpath $path)
                end
            end
            set args[$i] "file://$path"
            command curl $args
            return $status
        end
    end
    # curlie treats non-TTY stdin as POST body (-d@-); empty stdin avoids hangs.
    if command -q curlie
        set -l curlie_args $args
        if not contains -- -d $curlie_args; and not contains -- --data $curlie_args; and not contains -- --data-binary $curlie_args
            if not contains -- -X $curlie_args; and not contains -- --request $curlie_args
                set -a curlie_args -X GET
            end
        end
        command curlie $curlie_args </dev/null
        return $status
    end
    command curl $args
end

# realpath compatibility shim: prefer realpath; fall back to readlink -f.
function aur_realpath --argument-names path
    if command -q realpath
        command realpath -s -- $path
        return $status
    end
    if command -q readlink
        command readlink -f -- $path 2>/dev/null
        return $status
    end
    return 1
end

# SHA256 compatibility shim: prefer sha256sum; fall back to openssl dgst.
function aur_sha256 --argument-names path
    if command -q sha256sum
        command sha256sum $path 2>/dev/null | string split ' ' | head -1
        return $status
    end
    if command -q openssl
        command openssl dgst -sha256 $path 2>/dev/null | string replace -r '^.*= ' ''
        return $status
    end
    return 1
end

# Hostname shim: inetutils hostname optional; uname -n from coreutils is enough on minimal Arch.
function aur_hostname
    if command -q hostname
        hostname
        return 0
    end
    if command -q uname
        uname -n
        return 0
    end
    echo unknown
end
