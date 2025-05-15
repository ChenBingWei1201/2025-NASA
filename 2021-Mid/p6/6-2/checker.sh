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

# Function to get directory contents
get_dir_contents() {
    local dir_path="$1"
    unzip -l "$zip_file" 2>/dev/null | awk -v dir="$dir_path" '
        NR>3 && NF>=4 {
            if ($4 ~ "^" dir "[^/]+$") {
                gsub("^" dir, "", $4)
                print $4
            }
        }'
}

# Function to get subdirectories
get_subdirs() {
    local dir_path="$1"
    unzip -l "$zip_file" 2>/dev/null | awk -v dir="$dir_path" '
        NR>3 && NF>=4 && $4 ~ "^" dir "[^/]+/" {
            sub("^" dir, "", $4)
            sub("/.*", "", $4)
            print $4
        }' | sort -u
}

# Function to validate a directory against its spec
validate_directory() {
    local dir_path="$1"
    local spec="$2"
    
    # Check if spec is an array (files only)
    if [ "$(echo "$spec" | jq -r 'if type=="array" then "array" else "object" end')" = "array" ]; then
        # Get expected files from the array
        local expected_files=$(echo "$spec" | jq -r '.[]')
        
        # Get actual files in this directory (non-recursive)
        local actual_files=$(get_dir_contents "$dir_path")
        
        # Check for missing and forbidden files
        local missing=()
        local forbidden=()
        
        while IFS= read -r file_spec; do
            if [[ -z "$file_spec" ]]; then
                continue
            fi
            if [[ "$file_spec" =~ ^\^ ]]; then
                # Forbidden file
                local forbidden_file="${file_spec:1}"
                if echo "$actual_files" | grep -Fxq "$forbidden_file"; then
                    forbidden+=("$forbidden_file")
                fi
            else
                # Required file
                if ! echo "$actual_files" | grep -Fxq "$file_spec"; then
                    missing+=("$file_spec")
                fi
            fi
        done <<< "$expected_files"
        
        if [ ${#missing[@]} -gt 0 ]; then
            echo "Error: Missing required files in ${dir_path%/}: ${missing[*]}" >&2
            return 1
        fi
        
        if [ ${#forbidden[@]} -gt 0 ]; then
            echo "Error: Found forbidden files in ${dir_path%/}: ${forbidden[*]}" >&2
            return 1
        fi
        
        return 0
    else
        # Spec is an object (has subdirectories and/or _files)
        
        # Check _files if present
        local files_spec=$(echo "$spec" | jq -r '._files')
        if [ "$files_spec" != "null" ]; then
            validate_directory "$dir_path" "$files_spec" || return 1
        fi
        
        # Get list of expected subdirectories
        local subdirs_spec=$(echo "$spec" | jq -r 'del(._files) | keys[]')
        
        # Convert subdirs_spec to array for easier comparison
        local -a expected_subdirs=()
        while IFS= read -r subdir; do
            if [[ -n "$subdir" ]]; then
                expected_subdirs+=("$subdir")
            fi
        done <<< "$subdirs_spec"
        
        # Get actual subdirectories
        local all_subdirs=$(get_subdirs "$dir_path")
        
        # Convert all_subdirs to array
        local -a actual_subdirs=()
        while IFS= read -r subdir; do
            if [[ -n "$subdir" ]]; then
                actual_subdirs+=("$subdir")
            fi
        done <<< "$all_subdirs"
        
        # Check each subdirectory in spec exists and is valid
        for expected_subdir in "${expected_subdirs[@]}"; do
            # Get the spec for this subdirectory
            local subdir_spec=$(echo "$spec" | jq -r ".\"$expected_subdir\"")
            
            # Check if the subdirectory exists in the zip
            local full_path="${dir_path}${expected_subdir}/"
            if ! echo "$all_subdirs" | grep -Fxq "$expected_subdir"; then
                echo "Error: Missing required subdirectory: ${full_path%/}" >&2
                return 1
            fi
            
            # Recursively validate the subdirectory
            validate_directory "$full_path" "$subdir_spec" || return 1
        done
        
        # Check for unexpected subdirectories
        for actual_subdir in "${actual_subdirs[@]}"; do
            local found=0
            for expected_subdir in "${expected_subdirs[@]}"; do
                if [[ "$actual_subdir" = "$expected_subdir" ]]; then
                    found=1
                    break
                fi
            done
            
            if [ "$found" -eq 0 ]; then
                echo "Error: Unexpected subdirectory found: ${dir_path%/}/$actual_subdir" >&2
                return 1
            fi
        done
        
        return 0
    fi
}

# Extract top directory name from JSON
top_dir=$(jq -r 'keys[0]' "$json_file")
if [ -z "$top_dir" ]; then
    echo "Error: Invalid JSON format - no top directory found" >&2
    exit 1
fi

# Get the specification for the top directory
spec=$(jq -r ".\"$top_dir\"" "$json_file")

# Check zip file structure - verify single top-level directory exists
zip_contents=$(unzip -l "$zip_file" 2>/dev/null | awk 'NR>3 && NF>=4 {print $4}')

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

# Start recursive validation from the top directory
validate_directory "$top_dir/" "$spec"

# Exit with appropriate status
if [ $? -eq 0 ]; then
    exit 0
else
    exit 1
fi