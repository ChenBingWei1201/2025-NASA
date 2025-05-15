#!/bin/bash

# Directory where test cases are stored
TESTCASES_DIR="testcases"

# Path to your checker script
CHECKER_SCRIPT="./checker.sh"

# Output file for results
RESULTS_FILE="6-1.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Initialize results file
echo "Test Results - $(date)" > $RESULTS_FILE
echo "=========================" >> $RESULTS_FILE
echo "" >> $RESULTS_FILE

# Function to run a single test case
run_test() {
    local test_num=$1
    local expected_result=$2
    local test_dir="${TESTCASES_DIR}/${test_num}"
    local result_msg=""
    local console_msg=""
    
    echo "=== Running Test ${test_num} ===" | tee -a $RESULTS_FILE
    
    # Check if test files exist
    if [ ! -f "${test_dir}/test${test_num}.zip" ] || [ ! -f "${test_dir}/format${test_num}.json" ]; then
        result_msg="ERROR: Test files missing for test ${test_num}"
        console_msg="${RED}${result_msg}${NC}"
        echo "$result_msg" >> $RESULTS_FILE
        echo "$console_msg"
        echo "" >> $RESULTS_FILE
        return 1
    fi
    
    # Run the checker
    "${CHECKER_SCRIPT}" "${test_dir}/test${test_num}.zip" "${test_dir}/format${test_num}.json"
    local result=$?
    
    # Check result and prepare messages
    if [ "$result" -eq "$expected_result" ]; then
        result_msg="PASS: Test ${test_num} returned ${result} (expected ${expected_result})"
        console_msg="${GREEN}${result_msg}${NC}"
    else
        result_msg="FAIL: Test ${test_num} returned ${result} (expected ${expected_result})"
        console_msg="${RED}${result_msg}${NC}"
    fi
    
    # Output to both console and results file
    echo "$result_msg" >> $RESULTS_FILE
    echo "$console_msg"
    echo "" >> $RESULTS_FILE
}

# Run all test cases
echo "Starting test suite..." | tee -a $RESULTS_FILE
echo "" >> $RESULTS_FILE

# Test 1: Basic Valid Case
run_test 1 0

# Test 2: Missing Required File
run_test 2 1

# Test 3: Contains Forbidden File
run_test 3 1

# Test 4: Extra Files Allowed
run_test 4 0

# Test 5: Wrong Top Directory Name
run_test 5 1

# Test 6: Multiple Top-Level Directories
run_test 6 1

# Test 7: Empty Directory
run_test 7 0

# Test 8: Complex Forbidden Patterns
run_test 8 1

# Test 9: Multiple Required Files
run_test 9 0

# Test 10: Subdirectory Present (Invalid for 6.1)
run_test 10 1

echo "Test suite completed." | tee -a $RESULTS_FILE
echo "" >> $RESULTS_FILE

# Print summary to console
echo -e "\nTest results have been saved to ${GREEN}${RESULTS_FILE}${NC}"
echo "Here's a quick summary:"
grep -e "PASS" -e "FAIL" -e "ERROR" $RESULTS_FILE