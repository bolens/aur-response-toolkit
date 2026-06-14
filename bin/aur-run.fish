#!/usr/bin/env fish
# Portable entry point — resolves install path via bin/ location, not the user's clone cwd.
set -g AUR_RESPONSE_DIR (dirname (dirname (status filename)))
exec fish $AUR_RESPONSE_DIR/run.fish $argv
