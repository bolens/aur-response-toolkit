# Fish completions for aur-response / run.fish (full-scan orchestrator)
complete -c aur-response -f
complete -c run.fish -f

for cmd in aur-response run.fish
    complete -c $cmd -s h -l help -d 'Show help'
    complete -c $cmd -l version -d 'Print toolkit version'
    complete -c $cmd -l local -d 'Use bundled Atomic Arch list (offline)'
    complete -c $cmd -l audit -d 'Always run credential audit + rotation hints'
    complete -c $cmd -l report -d 'Append output to reports/'
    complete -c $cmd -l quiet -d 'Suppress scan stdout'
    complete -c $cmd -l quick -d 'Faster narrower artifact scans'
    complete -c $cmd -l json -d 'Print JSON summary to stdout'
    complete -c $cmd -l recover -d 'Interactive recovery wizard'
    complete -c $cmd -l skip-pkg-check -d 'Skip step 1 package list checks'
    complete -c $cmd -l if-compromised -d 'Fail audit only when compromise detected'
    complete -c $cmd -l all-time -d 'Ignore compromise date window'
    complete -c $cmd -l chaos-rat -d 'Also scan Chaos RAT packages'
    complete -c $cmd -l shai-hulud -d 'Also scan Mini Shai-Hulud packages'
    complete -c $cmd -l xeactor -d 'Also scan 2018 xeactor packages'
    complete -c $cmd -l fail-on -d 'Exit policy' -xa 'all compromise chaos-rat shai-hulud xeactor none'
    complete -c $cmd -l prune-days -d 'Delete reports older than N days' -r
end
