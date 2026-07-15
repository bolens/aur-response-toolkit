#!/usr/bin/env fish

# Test runner: discovers suites and runs them (optionally in parallel).
# Set AUR_TEST_JOBS=N to cap concurrency (default: nproc, or 4).

set -l test_dir (dirname (status filename))
set -g AUR_RESPONSE_DIR (dirname $test_dir)
source $AUR_RESPONSE_DIR/lib/bootstrap.fish

function _aur_discover_test_suites --argument-names root
    aur_find $root/unit $root/integration -name 'test-*.fish' -type f 2>/dev/null | sort
end

function _aur_test_job_limit
    if set -q AUR_TEST_JOBS; and string match -qr '^[1-9][0-9]*$' -- "$AUR_TEST_JOBS"
        echo $AUR_TEST_JOBS
        return
    end
    if command -q nproc
        set -l n (nproc 2>/dev/null | string trim)
        if string match -qr '^[1-9][0-9]*$' -- "$n"
            echo $n
            return
        end
    end
    echo 4
end

function _aur_running_job_count
    set -l pids (jobs -p 2>/dev/null)
    count $pids
end

set -l suites (_aur_discover_test_suites $test_dir)
set -l max_jobs (_aur_test_job_limit)
set -l results (mktemp -d)
set -l idx 0

echo "AUR response toolkit — test suite"
echo "================================="
echo "Suites: "(count $suites)"  parallel jobs: $max_jobs"
echo ""

for suite in $suites
    set idx (math $idx + 1)
    set -l id $idx
    while test (_aur_running_job_count) -ge $max_jobs
        sleep 0.05
    end
    begin
        fish $suite >$results/$id.out 2>&1
        echo $status >$results/$id.status
        echo $suite >$results/$id.path
    end &
end

wait

set -l failed_suites 0
set -l passed_suites 0

for id in (seq $idx)
    set -l st (cat $results/$id.status | string trim)
    set -l path (cat $results/$id.path | string trim)
    cat $results/$id.out
    if test "$st" = 0
        set passed_suites (math $passed_suites + 1)
    else
        set failed_suites (math $failed_suites + 1)
        echo "[suite exit $st] $path"
    end
end

rm -rf $results

echo ""
echo "================================="
if test $failed_suites -eq 0
    echo "All $passed_suites suite(s) passed."
    exit 0
end
echo "$failed_suites suite(s) failed, $passed_suites passed."
exit 1
