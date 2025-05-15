#!/bin/bash

# Make the script executable with proper permissions
chmod +x "$0"

# Default values
data_dir="testcases"
time_limit=1
checker=""
subtasks_file=""

# Parse options
while getopts "d:c:t:s:" opt; do
  case $opt in
    d) data_dir="$OPTARG" ;;
    c) checker="$OPTARG" ;;
    t) time_limit="$OPTARG" ;;
    s) subtasks_file="$OPTARG" ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
  esac
done

# Shift away the options
shift $((OPTIND - 1))

# The C file is the last argument
c_file="$1"

# Check if the file exists
if [ ! -f "$c_file" ]; then
    echo "Error: File $c_file not found"
    exit 1
fi

# Check if data directory exists
if [ ! -d "$data_dir" ]; then
    echo "Error: $data_dir directory not found"
    exit 1
fi

# Compile the C file
executable_name="program.out"
gcc -o "$executable_name" "$c_file" 2>/dev/null

# Function to pad a string with spaces to reach length 20
pad_to_20() {
    name="$1"
    printf "%-20s" "$name"
}

# Print the header
echo "------ JudgeGuest ------"
echo "Data DIR: $data_dir"
echo "Test on: $c_file"
echo "------------------------"

# Get all test case names (without extensions) and sort them
test_cases=$(find "$data_dir" -name "*.in" | sort | sed "s|$data_dir/||" | sed 's|\.in$||')

# Store test results for later use with subtasks
declare -A test_results

# Process each test case
for test_case in $test_cases; do
    # Set up file paths
    input_file="$data_dir/${test_case}.in"
    answer_file="$data_dir/${test_case}.ans"
    output_file="${test_case}.out"

    # Run the program with specified timeout
    timeout "${time_limit}s" ./"$executable_name" < "$input_file" > "$output_file" 2>/dev/null
    
    # Check the result
    if [ $? -eq 124 ]; then
        # Timeout occurred (Time Limit Exceeded)
        verdict="Time Limit Exceeded"
    else
        # If checker is provided, use it; otherwise, use diff
        if [ -n "$checker" ]; then
            ./"$checker" "$input_file" "$answer_file" "$output_file" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                verdict="Accepted"
            else
                verdict="Wrong Answer"
            fi
        else
            diff -Z "$output_file" "$answer_file" >/dev/null
            if [ $? -eq 0 ]; then
                verdict="Accepted"
            else
                verdict="Wrong Answer"
            fi
        fi
    fi
    
    # Store the result for subtask evaluation
    test_results["$test_case"]="$verdict"
    
    # Print the result
    echo "$(pad_to_20 "$test_case")$verdict"

    # Clean up output file
    rm -f "$output_file"
done

# Function to check if a subtask passes
# This is a recursive function that handles dependencies
check_subtask() {
    local subtask_name="$1"
    local visited="$2"
    
    # If we've already evaluated this subtask, return its result
    if [[ -n "${subtask_status[$subtask_name]}" ]]; then
        if [ "${subtask_status[$subtask_name]}" = "Passed" ]; then
            return 0
        else
            return 1
        fi
    fi
    
    # Check if we're in a cycle (this shouldn't happen per the problem statement)
    if [[ "$visited" == *"|$subtask_name|"* ]]; then
        # Cycle detected - should not happen according to the problem statement
        echo "Error: Dependency cycle detected involving $subtask_name" >&2
        return 1
    fi
    
    # Mark this subtask as visited for cycle detection
    visited="$visited|$subtask_name|"
    
    # Get testcase patterns for this subtask
    local testcase_patterns=$(jq -r ".[\"$subtask_name\"].testcases[]" "$subtasks_file" 2>/dev/null)
    if [ $? -ne 0 ]; then
        # If not an array, get as a single string
        testcase_patterns=$(jq -r ".[\"$subtask_name\"].testcases" "$subtasks_file")
    fi
    
    # Check if all matching testcases passed
    local all_testcases_passed=true
    local matched_any=false
    
    for pattern in $testcase_patterns; do
        for test_case in $test_cases; do
            # Check if test_case matches the pattern
            echo "$test_case" | grep -E "$pattern" >/dev/null
            if [ $? -eq 0 ]; then  # Match found
                matched_any=true
                if [ "${test_results["$test_case"]}" != "Accepted" ]; then
                    all_testcases_passed=false
                    break 2  # Break out of both loops
                fi
            fi
        done
    done
    
    if [ "$matched_any" = false ] || [ "$all_testcases_passed" = false ]; then
        subtask_status[$subtask_name]="Failed"
        return 1
    fi
    
    # Check dependencies (included subtasks)
    # Get the dependencies if they exist
    local dependencies=$(jq -r ".[\"$subtask_name\"].include[]" "$subtasks_file" 2>/dev/null)
    if [ $? -eq 0 ]; then  # Dependencies exist
        for dep in $dependencies; do
            check_subtask "$dep" "$visited"
            if [ $? -ne 0 ]; then  # Dependency failed
                subtask_status[$subtask_name]="Failed"
                return 1
            fi
        done
    fi
    
    # If we got here, the subtask passed
    subtask_status[$subtask_name]="Passed"
    return 0
}

# Process subtasks if a subtasks file is provided
if [ -n "$subtasks_file" ] && [ -f "$subtasks_file" ]; then
    # Extract subtask names and sort them
    subtask_names=$(jq -r 'keys[]' "$subtasks_file" | sort)
    
    echo ""  # Empty line before subtask results
    
    # Create associative array to store subtask status
    declare -A subtask_status
    
    # Evaluate each subtask (with dependencies)
    for subtask_name in $subtask_names; do
        check_subtask "$subtask_name" ""
    done
    
    # Calculate total score and print results
    total_score=0
    
    for subtask_name in $subtask_names; do
        # Get score for this subtask
        score=$(jq -r ".[\"$subtask_name\"].score" "$subtasks_file")
        
        # Output result and add to total score if passed
        verdict="${subtask_status[$subtask_name]}"
        if [ "$verdict" = "Passed" ]; then
            total_score=$((total_score + score))
        fi
        
        # Print subtask result
        echo "Subtask $(pad_to_20 "$subtask_name")$verdict"
    done
    
    echo "Total Score: $total_score"
fi

# Clean up executable
rm -f "$executable_name"