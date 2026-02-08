#!/bin/bash

echo "YCSB Benchmark Suite - Running All Workloads"
echo "=============================================="
echo ""

workloads=("a" "b" "c" "d" "e" "f")
results_dir="/tmp/ycsb_results"
mkdir -p "$results_dir"

for wl in "${workloads[@]}"; do
    echo "Running Workload $wl..."
    
    # Restart server with fresh data
    # pkill shinydb 2>/dev/null
    # sleep 1
    # rm -rf /tmp/shinydb/data
    # cd shinydb && ./zig-out/bin/shinydb --port 23469 --data-dir /tmp/shinydb/data > /tmp/shinydb.log 2>&1 &
    sleep 2
    
    # Run workload
    # cd ../shinydb-ycsb
    ./zig-out/bin/shinydb-ycsb workload-$wl > "$results_dir/workload-$wl.txt" 2>&1
    
    echo "Workload $wl complete"
    echo ""
done

echo "All workloads complete! Results saved in $results_dir"
