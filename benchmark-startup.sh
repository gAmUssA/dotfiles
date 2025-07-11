#!/usr/bin/env zsh

# Shell startup performance benchmark

echo "🚀 Benchmarking zsh startup performance..."
echo

# Test multiple runs
total_time=0
runs=10

echo "Running $runs startup tests..."
for i in {1..$runs}; do
    # Use a fresh shell instance for each test
    duration=$(zsh -c "
        start_time=\$(date +%s%N)
        source /Users/vikgamov/projects/dotfiles/.zshrc > /dev/null 2>&1
        end_time=\$(date +%s%N)
        echo \$(( (end_time - start_time) / 1000000 ))
    ")
    
    total_time=$((total_time + duration))
    printf "Run %2d: %4dms\n" $i $duration
done

average_time=$((total_time / runs))

echo
echo "📊 Results:"
echo "  Average startup time: ${average_time}ms"
echo "  Total time for $runs runs: ${total_time}ms"

# Performance categories
if [[ $average_time -lt 100 ]]; then
    echo "  🟢 Excellent performance (< 100ms)"
elif [[ $average_time -lt 200 ]]; then
    echo "  🟡 Good performance (< 200ms)"
elif [[ $average_time -lt 500 ]]; then
    echo "  🟠 Acceptable performance (< 500ms)"
else
    echo "  🔴 Needs optimization (> 500ms)"
fi

echo
echo "💡 Tips:"
echo "  • To profile: uncomment zprof lines in .zshrc"
echo "  • To test completion installer: rm ~/.completion-last-check"
echo "  • Current completion check interval: 7 days"