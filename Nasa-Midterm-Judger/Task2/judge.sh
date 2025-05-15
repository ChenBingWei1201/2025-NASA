#!/bin/bash

# Make the script executable with proper permissions
chmod +x "$0"

# Default values
data_dir="testcases"
time_limit=1
checker=""

# Parse options
while getopts "d:c:t:" opt; do
  case $opt in
    d) data_dir="$OPTARG" ;;
    c) checker="$OPTARG" ;;
    t) time_limit="$OPTARG" ;;
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

# Function to pad the test case name with spaces to reach length 20
pad_testcase_name() {
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
    
    # Print the result
    echo "$(pad_testcase_name "$test_case")$verdict"

    # Clean up output file
    rm -f "$output_file"
done

# Clean up executable
rm -f "$executable_name"