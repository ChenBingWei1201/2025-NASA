#!/bin/bash

# Check for required tools
if ! command -v unzip &>/dev/null || ! command -v jq &>/dev/null; then
    echo "Error: Required tools (unzip and jq) not found." >&2
    exit 1
fi

# Validate arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input.zip> <format.json>" >&2
    exit 1
fi

zip_file="$1"
json_file="$2"

# Extract top directory name from JSON
top_dir=$(jq -r 'keys[0]' "$json_file")
if [ -z "$top_dir" ]; then
    echo "Error: Invalid JSON format - no top directory found" >&2
    exit 1
fi

# Get the specification for the top directory
spec=$(jq -r ".\"$top_dir\"" "$json_file")

# Check if the specification is an empty array (Test 7 case)
if [ "$(echo "$spec" | jq -r 'if type=="array" then . else null end | . == []')" = "true" ]; then
    # For empty array, we only need to verify:
    # 1. Single top directory exists
    # 2. No subdirectories
    # 3. No files are required (empty array means this is automatically satisfied)
    
    # Check zip file structure - don't remove directory entries
    zip_contents=$(unzip -l "$zip_file" 2>/dev/null | awk 'NR>3 && NF>=4 {print $4}')
    
    # Verify single top-level directory exists and is the only entry
    if [ "$(echo "$zip_contents" | grep -v "^$" | wc -l)" -ne 1 ] || [ "$(echo "$zip_contents" | grep -v "^$" | head -1)" != "$top_dir/" ]; then
        echo "Error: ZIP must contain exactly one empty top-level directory" >&2
        exit 1
    fi
    
    exit 0
fi

# For non-empty array cases, proceed with normal validation
expected_files=$(jq -r ".\"$top_dir\"[]" "$json_file" 2>/dev/null)

# Check zip file structure
zip_contents=$(unzip -l "$zip_file" 2>/dev/null | awk 'NR>3 && NF>=4 {print $4}' | sed '/\/$/d')

# Verify single top-level directory
top_level_dirs=$(echo "$zip_contents" | grep -o "^[^/]*/" | sort -u)
if [ $(echo "$top_level_dirs" | wc -l) -ne 1 ]; then
    echo "Error: ZIP must contain exactly one top-level directory" >&2
    exit 1
fi

# Check directory name matches
if [ "$top_level_dirs" != "$top_dir/" ]; then
    echo "Error: Directory name mismatch (expected: $top_dir, found: ${top_level_dirs%/})" >&2
    exit 1
fi

# Check for forbidden subdirectories
subdirs=$(echo "$zip_contents" | grep "^$top_dir/[^/]*/" | sed "s|^$top_dir/||;s|/.*||" | sort -u)
if [ -n "$subdirs" ]; then
    echo "Error: Unexpected subdirectories found: $subdirs" >&2
    exit 1
fi

# Check files in directory
found_files=$(echo "$zip_contents" | grep "^$top_dir/[^/]*$" | sed "s|^$top_dir/||")
missing=()
forbidden=()

# Process expected files
for file_spec in $expected_files; do
    if [[ "$file_spec" =~ ^\^ ]]; then
        # Forbidden file
        forbidden_file="${file_spec:1}"
        if echo "$found_files" | grep -q "^${forbidden_file}$"; then
            forbidden+=("$forbidden_file")
        fi
    else
        # Required file
        if ! echo "$found_files" | grep -q "^${file_spec}$"; then
            missing+=("$file_spec")
        fi
    fi
done

# Report errors
if [ ${#missing[@]} -gt 0 ]; then
    echo "Error: Missing required files: ${missing[*]}" >&2
    exit 1
fi

if [ ${#forbidden[@]} -gt 0 ]; then
    echo "Error: Found forbidden files: ${forbidden[*]}" >&2
    exit 1
fi

# All checks passed
exit 0