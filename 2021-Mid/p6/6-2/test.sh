#!/bin/bash

# Check if checker.sh exists
CHECKER="./checker.sh"
if [ ! -f "$CHECKER" ]; then
    echo "Error: checker.sh not found in parent directory" | tee -a 6-2.txt
    exit 1
fi

# Clear previous results
> 6-2.txt

# Run all test cases
for testdir in $(ls -v testcases); do
    if [ -d "testcases/$testdir" ]; then
        echo "=== Running test $testdir ===" | tee -a 6-2.txt
        cat "testcases/$testdir/description.txt" | tee -a 6-2.txt
        
        # Run the test
        "$CHECKER" "testcases/$testdir/input.zip" "testcases/$testdir/format.json" >> 6-2.txt 2>&1
        result=$?
        
        # Print result
        if [ $result -eq 0 ]; then
            echo "Result: PASSED (exit code 0)" | tee -a 6-2.txt
        else
            echo "Result: FAILED (exit code $result)" | tee -a 6-2.txt
        fi
        
        echo | tee -a 6-2.txt
    fi
done

echo "All tests completed. Results saved to 6-2.txt"