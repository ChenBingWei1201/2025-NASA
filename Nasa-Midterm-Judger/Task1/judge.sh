#!/bin/bash

# Make the script executable with proper permissions
chmod +x "$0"

# Check if there's at least one argument (the C file)
if [ $# -lt 1 ]; then
    echo "Usage: $0 [option] code.c"
    exit 1
fi

# The C file is the last argument
c_file="${!#}"

# Check if the file exists
if [ ! -f "$c_file" ]; then
    echo "Error: File $c_file not found"
    exit 1
fi

# Check if testcases directory exists
if [ ! -d "testcases" ]; then
    echo "Error: testcases directory not found"
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
echo "Data DIR: testcases"
echo "Test on: $c_file"
echo "------------------------"

# Get all test case names (without extensions) and sort them
test_cases=$(find testcases -name "*.in" | sort | sed 's|testcases/||' | sed 's|\.in$||')

# Process each test case
for test_case in $test_cases; do
    # Set up file paths
    input_file="testcases/${test_case}.in"
    answer_file="testcases/${test_case}.ans"
    output_file="output.tmp"

    # Run the program with timeout of 1 second
    timeout 0.5s ./"$executable_name" < "$input_file" > "$output_file" 2>/dev/null
    
    # Check the result
    if [ $? -eq 124 ]; then
        # Timeout occurred (Time Limit Exceeded)
        verdict="Time Limit Exceeded"
    else
        # Compare output with expected answer
        diff -Z "$output_file" "$answer_file" >/dev/null
        if [ $? -eq 0 ]; then
            verdict="Accepted"
        else
            verdict="Wrong Answer"
        fi
    fi
    
    # Print the result
    echo "$(pad_testcase_name "$test_case")$verdict"

    # Clean up output file
    rm -f "$output_file"
done

# Clean up executable
rm -f "$executable_name"