#!/bin/bash

# Create directory structure
mkdir -p 6-2/testcases
cd 6-2/testcases || exit

# Clean previous test cases
rm -rf *

# Function to create a test case
create_test_case() {
    local test_num=$1
    local test_name=$2
    local json_content=$3
    local setup_commands=$4
    
    # Create test directory
    mkdir -p "$test_num"
    cd "$test_num" || exit
    
    # Create test description file
    echo "Test $test_num: $test_name" > description.txt
    
    # Create format.json
    echo "$json_content" > format.json
    
    # Create test files based on setup commands
    mkdir -p temp_test_dir
    cd temp_test_dir || exit
    eval "$setup_commands"
    
    # Create zip file
    zip -r "../input.zip" . > /dev/null
    
    # Clean up
    cd ..
    rm -rf temp_test_dir
    cd ..
}

# Test Case 1: Simple valid case with files only
create_test_case 1 "Simple valid case with files only" \
'{
  "testdir": ["file1.txt", "file2.txt", "^forbidden.txt"]
}' \
'
mkdir -p testdir
touch testdir/file1.txt
touch testdir/file2.txt
'

# Test Case 2: Missing required file
create_test_case 2 "Missing required file" \
'{
  "testdir": ["file1.txt", "file2.txt", "^forbidden.txt"]
}' \
'
mkdir -p testdir
touch testdir/file1.txt
'

# Test Case 3: Contains forbidden file
create_test_case 3 "Contains forbidden file" \
'{
  "testdir": ["file1.txt", "file2.txt", "^forbidden.txt"]
}' \
'
mkdir -p testdir
touch testdir/file1.txt
touch testdir/file2.txt
touch testdir/forbidden.txt
'

# Test Case 4: Valid nested directory structure
create_test_case 4 "Valid nested directory structure" \
'{
  "testdir": {
    "subdir1": ["file1.txt"],
    "subdir2": {
      "subsubdir": ["file2.txt"],
      "_files": ["config.txt"]
    },
    "_files": ["^forbidden.txt", "README.md"]
  }
}' \
'
mkdir -p testdir/subdir1
mkdir -p testdir/subdir2/subsubdir
touch testdir/subdir1/file1.txt
touch testdir/subdir2/subsubdir/file2.txt
touch testdir/subdir2/config.txt
touch testdir/README.md
'

# Test Case 5: Unexpected subdirectory
create_test_case 5 "Unexpected subdirectory" \
'{
  "testdir": {
    "subdir1": ["file1.txt"],
    "_files": ["README.md"]
  }
}' \
'
mkdir -p testdir/subdir1
mkdir -p testdir/unexpected
touch testdir/subdir1/file1.txt
touch testdir/README.md
'

# Test Case 6: Empty directory (valid)
create_test_case 6 "Empty directory (valid)" \
'{
  "testdir": []
}' \
'
mkdir -p testdir
'

# Test Case 7: Complex valid case with multiple levels
create_test_case 7 "Complex valid case with multiple levels" \
'{
  "project": {
    "src": {
      "main": ["Main.java"],
      "test": ["Test.java"],
      "_files": ["build.gradle"]
    },
    "docs": ["README.md", "LICENSE"],
    "config": {
      "_files": ["^temp.conf", "settings.conf"]
    },
    "_files": ["^.env", "Makefile"]
  }
}' \
'
mkdir -p project/src/main
mkdir -p project/src/test
mkdir -p project/config
mkdir -p project/docs
touch project/src/main/Main.java
touch project/src/test/Test.java
touch project/src/build.gradle
touch project/docs/README.md
touch project/docs/LICENSE
touch project/config/settings.conf
touch project/Makefile
'

# Test Case 8: Complex invalid case with multiple issues
create_test_case 8 "Complex invalid case with multiple issues" \
'{
  "project": {
    "src": {
      "main": ["Main.java"],
      "test": ["Test.java"],
      "_files": ["build.gradle"]
    },
    "docs": ["README.md", "LICENSE"],
    "config": {
      "_files": ["^temp.conf", "settings.conf"]
    },
    "_files": ["^.env", "Makefile"]
  }
}' \
'
mkdir -p project/src/main
mkdir -p project/src/test
mkdir -p project/config
mkdir -p project/docs
mkdir -p project/unexpected
touch project/src/main/Main.java
touch project/src/test/Test.java
touch project/src/build.gradle
touch project/docs/README.md
touch project/config/settings.conf
touch project/config/temp.conf
touch project/.env
touch project/Makefile
'

echo "Test cases generated in 6-2/testcases directory"