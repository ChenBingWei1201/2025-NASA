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

# Process subtasks if a subtasks file is provided
if [ -n "$subtasks_file" ] && [ -f "$subtasks_file" ]; then
    # Extract subtask names and sort them
    subtask_names=$(jq -r 'keys[]' "$subtasks_file" | sort)
    
    echo ""  # Empty line before subtask results
    
    total_score=0
    
    for subtask_name in $subtask_names; do
        # Get score for this subtask
        score=$(jq -r ".[\"$subtask_name\"].score" "$subtasks_file")
        
        # Get testcase patterns for this subtask (as an array)
        testcase_patterns=$(jq -r ".[\"$subtask_name\"].testcases[]" "$subtasks_file" 2>/dev/null)
        if [ $? -ne 0 ]; then
            # If not an array, get as a single string
            testcase_patterns=$(jq -r ".[\"$subtask_name\"].testcases" "$subtasks_file")
        fi
        
        # Check if all matching testcases passed
        all_passed=true
        matched_any=false
        
        for pattern in $testcase_patterns; do
            for test_case in $test_cases; do
                # Check if test_case matches the pattern
                echo "$test_case" | grep -E "$pattern" >/dev/null
                if [ $? -eq 0 ]; then  # Match found
                    matched_any=true
                    if [ "${test_results["$test_case"]}" != "Accepted" ]; then
                        all_passed=false
                    fi
                fi
            done
        done
        
        # Determine verdict and update score
        if [ "$all_passed" = true ] && [ "$matched_any" = true ]; then
            verdict="Passed"
            total_score=$((total_score + score))
        else
            verdict="Failed"
        fi
        
        # Print subtask result
        echo "Subtask $(pad_to_20 "$subtask_name")$verdict"
    done
    
    echo "Total Score: $total_score"
fi

# Clean up executable
rm -f "$executable_name"