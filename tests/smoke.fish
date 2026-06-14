#!/usr/bin/env fish

# Backward-compatible alias for the full suite
exec fish (dirname (status filename))/run-all.fish $argv
