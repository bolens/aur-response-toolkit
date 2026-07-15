#!/usr/bin/env fish
#
# Validate Conventional Commits subjects (no Node/commitlint dependency).
#
# Usage:
#   fish scripts/check-conventional-commit.fish --message 'feat: add foo'
#   git log -1 --format=%s | fish scripts/check-conventional-commit.fish
#   fish scripts/check-conventional-commit.fish --range ORIGIN_BASE...HEAD
#
# Exit 0 = ok, 1 = invalid subject(s).

set -l messages
set -l range ""

set -l i 1
while test $i -le (count $argv)
    set -l arg $argv[$i]
    switch $arg
        case --help -h
            echo "Usage: check-conventional-commit.fish [--message TEXT]..."
            echo "       check-conventional-commit.fish --range BASE...HEAD"
            echo "       echo 'feat: foo' | check-conventional-commit.fish"
            exit 0
        case --message
            set i (math $i + 1)
            if test $i -gt (count $argv)
                echo "error: --message requires a value" >&2
                exit 1
            end
            set -a messages $argv[$i]
        case '--message=*'
            set -a messages (string sub -s 11 -- $arg)
        case --range
            set i (math $i + 1)
            if test $i -gt (count $argv)
                echo "error: --range requires BASE...HEAD" >&2
                exit 1
            end
            set range $argv[$i]
        case '--range=*'
            set range (string sub -s 9 -- $arg)
        case '-*'
            echo "Unknown option: $arg (see --help)" >&2
            exit 1
        case '*'
            set -a messages $arg
    end
    set i (math $i + 1)
end

if test -n "$range"
    for s in (git log --format=%s --no-merges "$range")
        set -a messages $s
    end
end

if test (count $messages) -eq 0; and not isatty stdin
    while read -l line
        test -n "$line"; and set -a messages $line
    end
end

if test (count $messages) -eq 0
    echo "error: no commit messages to check" >&2
    exit 1
end

# type(scope)!: subject — type required; scope/! optional; subject 1–72 chars after ": "
set -l pattern '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-zA-Z0-9][a-zA-Z0-9._/-]*\))?(!)?: [^ ].{0,71}$'

set -l failed 0
for msg in $messages
    # Allow Dependabot-style subjects that we rewrite via dependabot.yml prefix
    if string match -qr $pattern -- $msg
        continue
    end
    echo "invalid conventional commit subject:" >&2
    echo "  $msg" >&2
    set failed 1
end

if test $failed -ne 0
    echo "" >&2
    echo "Expected: <type>(optional-scope)!: <imperative summary>" >&2
    echo "Types: feat fix docs style refactor perf test build ci chore revert" >&2
    exit 1
end

exit 0
