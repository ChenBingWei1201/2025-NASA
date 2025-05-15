#!/usr/bin/env bash

# The argument can appear before, between, or after the options, but both the argument and options must appear after the subcommand.
usage() {
    echo "merkle-dir.sh - A tool for working with Merkle trees of directories."
    echo ""
    echo "Usage:"
    echo "  merkle-dir.sh <subcommand> [options] [<argument>]"
    echo "  merkle-dir.sh build <directory> --output <merkle-tree-file>"
    echo "  merkle-dir.sh gen-proof <path-to-leaf-file> --tree <merkle-tree-file> --output <proof-file>"
    echo "  merkle-dir.sh verify-proof <path-to-leaf-file> --proof <proof-file> --root <root-hash>"
    echo ""
    echo "Subcommands:"
    echo "  build          Construct a Merkle tree from a directory (requires --output)."
    echo "  gen-proof      Generate a proof for a specific file in the Merkle tree (requires --tree and --output)."
    echo "  verify-proof   Verify a proof against a Merkle root (requires --proof and --root)."
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message and exit."
    echo "  --output FILE  Specify an output file (required for build and gen-proof)."
    echo "  --tree FILE    Specify the Merkle tree file (required for gen-proof)."
    echo "  --proof FILE   Specify the proof file (required for verify-proof)."
    echo "  --root HASH    Specify the expected Merkle root hash (required for verify-proof)."
    echo ""
    echo "Examples:"
    echo "  merkle-dir.sh build dir1 --output dir1.mktree"
    echo "  merkle-dir.sh gen-proof file1.txt --tree dir1.mktree --output file1.proof"
    echo "  merkle-dir.sh verify-proof dir1/file1.txt --proof file1.proof --root abc123def456"
}

# Building a Merkle Tree
# ./merkle-dir.sh build <directory> --output <merkle-tree-file>
# ./merkle-dir.sh build dir1 --output dir1.mktree
build() {
    directory="$1"
    merkle_tree_file="$2"

    # Get all files in the directory and sort them
    files=($(find "$directory" -type f | LC_COLLATE=C sort | sed "s|$directory/||"))

    # Calculate the hash of each file
    leaf_hashes=()
    for file in "${files[@]}"; do
        hash=$(sha256sum "$directory/$file" | awk '{print $1}')
        leaf_hashes+=("$hash")
    done

    # Store the leaf level in the Merkle tree
    merkle_tree=()
    merkle_tree+=("$(IFS=:; echo "${leaf_hashes[*]}")")
    current_hashes=("${leaf_hashes[@]}")

    # Build the Merkle tree
    while ((${#current_hashes[@]} > 1)); do
        next_level=()
        level_hashes=()
        num_hashes=${#current_hashes[@]}

        for ((i = 0; i < num_hashes; i+=2)); do
            if (( i + 1 < num_hashes )); then
                # combine the two hashes
                combined="${current_hashes[i]}${current_hashes[i+1]}"
            else
                # odd node -> carry it up unchanged
                next_level+=("${current_hashes[i]}")
                continue  # Skip hashing this time
            fi

            # ensure proper binary concatenation before hashing
            next_hash=$(echo -n "$combined" | xxd -r -p | sha256sum | awk '{print $1}')
            next_level+=("$next_hash")
            level_hashes+=("$next_hash")
        done

        merkle_tree+=("$(IFS=:; echo "${level_hashes[*]}")")
        current_hashes=("${next_level[@]}")
    done

    root_hash="${current_hashes[0]}"

    # Write the Merkle tree to the merkle-tree-file
    {
        for file in "${files[@]}"; do
            echo "$file"
        done
        echo ""  # empty line

        for level in "${merkle_tree[@]}"; do
            echo "$level"
        done

    } > "$merkle_tree_file"
}

# Generating an Inclusion Proof
# ./merkle-dir.sh gen-proof <path-to-leaf-file> --tree <merkle-tree-file> --output <proof-file>
# ./merkle-dir.sh gen-proof hi.txt --tree dir1.mktree --output hi.txt.proof
gen_proof() {
    path_to_leaf_file="$1"
    merkle_tree_file="$2"
    proof_file="$3"

    # get the tree_size
    tree_size=$(awk 'NF == 0 {print NR-1; exit}' "$merkle_tree_file")

    # read the list of files (before the empty line)
    mapfile -t files < <(head -n "$tree_size" "$merkle_tree_file")

    # find the index of path_to_leaf_file in the list of files (1-based)
    leaf_index=-1
    for i in "${!files[@]}"; do
        if [[ "${files[i]}" == "$path_to_leaf_file" ]]; then
            leaf_index=$((i + 1)) # 1-based index
            break
        fi
    done

    # if the file is not found in the tree then exit
    if [[ "$leaf_index" -eq -1 ]]; then
        echo "ERROR: file not found in tree"
        exit 1
    fi

    # get the leaf hashes (first level)
    mapfile -t leaf_hashes < <(awk 'NF == 0 {exit} {print}' "$merkle_tree_file")

    # get the hash of the target leaf node
    target_hash="${leaf_hashes[$((leaf_index - 1))]}"

    # read Merkle Tree level (else)
    mapfile -t merkle_levels < <(awk 'NF == 0 {flag=1; next} flag' "$merkle_tree_file")

    # calculate the proof path
    proof=""
    IFS=$'\n' read -r -d '' -a leaves <<< "$(echo "${merkle_levels[0]}" | tr ':' '\n')"
    index=$((leaf_index - 1)) # 0-based index

    for level in "${merkle_levels[@]}"; do
        mapfile -t hashes < <(echo "$level" | tr ':' '\n')

        if (( index == 0 && ${#hashes[@]} == 1 )); then
            break
        fi

        if (( index % 2 == 0 )); then
            if (( index + 1 < ${#hashes[@]} )); then
                proof+=("${hashes[index + 1]}")  # right sibling node
            # else
            #     if (( index + 1 != $tree_size )); then
            #         proof+=("${leaves[${#leaves[@]}-1]}")
            #     fi
            fi
        else
            proof+=("${hashes[index - 1]}")  # left sibling node
        fi

        index=$(( index / 2 ))  # move up to the parent node
    done

    # Write the proof to the proof-file
    {
        echo -n "leaf_index:$leaf_index,tree_size:$tree_size"
        printf "%s\n" "${proof[@]}"
    } > "$proof_file"
}

# Function to calculate the height of the tree
calculate_height() {
    local log2_tree_size="$1"
    # Use bc to determine the height, rounding up if necessary
    echo $(echo "scale=0; ($log2_tree_size+0.9999999999999999)/1" | bc)
}

# Verifying an Inclusion Proof
# ./merkle-dir.sh verify-proof <path-to-leaf-file> --proof <proof-file> --root <root-hash>
# ./merkle-dir.sh verify-proof dir1/hi.txt --proof hi.txt.proof --root 61972 f8a5bf9925d70d34934dafced66756c5f9d7a80e3b265e61e5526155f83
verify_proof() {
    path_to_leaf_file="$1"
    proof_file="$2"
    root_hash="$3"

    # read proof-file
    read -r header < "$proof_file"
    leaf_index=$(echo "$header" | awk -F '[,:]' '{print $2}' | tr -d ' ') # 9
    tree_size=$(echo "$header" | awk -F '[,:]' '{print $4}' | tr -d ' ')  # 10

    # Validate tree_size and leaf_index
    if (( tree_size <= 0 )); then
        echo "Verification Failed"
        exit 1
    fi
    if (( leaf_index < 1 || leaf_index > tree_size )); then
        echo "Verification Failed"
        exit 1
    fi

    # read merkle path
    mapfile -t proof_hashes < <(tail -n +2 "$proof_file")

    # Calculate the expected number of proofs
    log2_tree_size=$(echo "l($tree_size)/l(2)" | bc -l)
    height=$(calculate_height "$log2_tree_size")
    
    # echo "log2_tree_size: $log2_tree_size and height: $height"
    # expected_proofs=0

    # if (( leaf_index == tree_size )); then
    #     expected_proofs=$(( height - 1 ))
    # else
    #     expected_proofs=$height
    # fi

    # # Check if the number of proofs matches the expected number
    # if (( ${#proof_hashes[@]} != expected_proofs )); then
    #     # echo "expected_proofs: $expected_proofs but got ${#proof_hashes[@]}"
    #     echo "Verification Failed"
    #     exit 1
    # fi

    # calculate the hash of the leaf node
    computed_hash=$(sha256sum "$path_to_leaf_file" | awk '{print $1}')

    # Algorithm to verify the proof
    k=$(( leaf_index - 1 )) # 0-based index
    n=$(( tree_size - 1 ))
    current_hash="$computed_hash"

    # traverse Merkle Path and calculate calculated_root
    for ((i = 0; i < ${#proof_hashes[@]}; i++)); do
        sibling_hash="${proof_hashes[i]}"

        if (( n == 0 )); then
            echo "Verification Failed"
            exit 1
        fi

        if (( (k & 1) == 1 || k == n )); then
            # k' is the right child or the last node of that level
            current_hash=$(echo -n "${sibling_hash}${current_hash}" | xxd -r -p | sha256sum | awk '{print $1}')
            while (( (k & 1) == 0 )); do
                k=$(( k >> 1 ))
                n=$(( n >> 1 ))
            done
        else
            # k' is left child
            current_hash=$(echo -n "${current_hash}${sibling_hash}" | xxd -r -p | sha256sum | awk '{print $1}')
        fi

        # right shift k' and n'
        k=$(( k >> 1 ))
        n=$(( n >> 1 ))
    done

    current_hash=$(echo "$current_hash" | tr '[:upper:]' '[:lower:]')
    root_hash=$(echo "$root_hash" | tr '[:upper:]' '[:lower:]')

    # compare the calculated root with the expected root
    if [[ "$current_hash" == "$root_hash" ]]; then
        echo "OK"
        exit 0
    else
        echo "Verification Failed"
        exit 1
    fi
}

# ./merkle-dir.sh -h --help -> exit 1
if [[ $1 = "-h" && $# -gt 1 ]]; then
    usage
    exit 1
fi

if [[ $1 = "--help" && $# -gt 1 ]]; then
    usage
    exit 1
fi

# subcommand and argument are void and options is `-h` or `--help`
if [[ $# -eq 1 && $1 = "-h" || $1 = "--help" ]]; then
	usage
	exit 0
fi

# subcommand is `build`
# options is `--output` <file> and <file> is an existing or non-existing regular file
# only one argument and it is an existing directory file
if [[ $1 = "build" ]]; then
    if [[ $# -ne 4 || ! " $* " =~ " --output " ]]; then
        usage
        exit 1
    fi

    directory=""
    merkle_tree_file=""

    # Track the number of non-option arguments found
    non_option_count=0

    # Iterate over the arguments to find the --output option and directory
    for (( i=2; i<=$#; i++ )); do
        if [[ ${!i} == "--output" ]]; then
            next_index=$((i+1))
            merkle_tree_file=${!next_index}
            i=$next_index  # Skip the next argument as it's part of the option
        elif [[ ! ${!i} =~ ^-- ]]; then
            # Increment non-option argument count
            non_option_count=$((non_option_count+1))
            # Assume the first non-option argument after the subcommand is the directory
            if [[ $non_option_count -eq 1 ]]; then
                directory=${!i}
            fi
        fi
    done

    if [[ -z $merkle_tree_file || -z $directory || ! -d $directory || -L $directory ]]; then
        usage
        exit 1
    fi

    if [[ -L $merkle_tree_file || -d $merkle_tree_file ]]; then
        usage
        exit 1
    fi

    build "$directory" "$merkle_tree_file"
fi

# subcommand is `gen-proof`
# options are `--output <file1>` and `--tree <file2>`. <file1> is an existing or non-existing regular file and <file2> is an existing regular file
# only one argument
if [[ $1 = "gen-proof" ]]; then
    if [[ $# -ne 6 || ! " $* " =~ " --output " || ! " $* " =~ " --tree " ]]; then
        usage
        exit 1
    fi

    proof_file=""
    merkle_tree_file=""
    path_to_leaf_file=""

    # Track the number of non-option arguments found
    non_option_count=0

    # Iterate over the arguments to find the --output and --tree options
    for (( i=2; i<=$#; i++ )); do
        if [[ ${!i} == "--output" ]]; then
            next_index=$((i+1))
            proof_file=${!next_index}
            i=$next_index  # Skip the next argument as it's part of the option
        elif [[ ${!i} == "--tree" ]]; then
            next_index=$((i+1))
            merkle_tree_file=${!next_index}
            i=$next_index  # Skip the next argument as it's part of the option
        elif [[ ! ${!i} =~ ^-- ]]; then
            # Increment non-option argument count
            non_option_count=$((non_option_count+1))
            # Assume the first non-option argument after the subcommand is the leaf file
            if [[ $non_option_count -eq 1 ]]; then
                path_to_leaf_file=${!i}
            fi
        fi
    done

    if [[ -z $merkle_tree_file || -z $path_to_leaf_file || ! -f $merkle_tree_file || -L $merkle_tree_file || -d $merkle_tree_file || -L $proof_file || -d $proof_file ]]; then
        usage
        exit 1
    fi

    gen_proof "$path_to_leaf_file" "$merkle_tree_file" "$proof_file"
fi

# subcommand is `verify-proof`
# options are `--proof <file>` and `--root <hash>`. <file> is an existing regular file and <hash> contains only the numbers 0 to 9 and the letters A to F, using either all uppercase or all lowercase letters.
# only one argument and it is an existing regular file
if [[ $1 = "verify-proof" ]]; then
	if [[ $# -ne 6 || ! " $* " =~ " --proof " || ! " $* " =~ " --root " ]]; then
		usage
		exit 1
	fi

	proof_file=""
	root_hash=""
	path_to_leaf_file=""

	# Track the number of non-option arguments found
	non_option_count=0

	# Iterate over the arguments to find the --proof and --root options
	for (( i=2; i<=$#; i++ )); do
		if [[ ${!i} == "--proof" ]]; then
			next_index=$((i+1))
			proof_file=${!next_index}
			i=$next_index  # Skip the next argument as it's part of the option
		elif [[ ${!i} == "--root" ]]; then
			next_index=$((i+1))
			root_hash=${!next_index}
			i=$next_index  # Skip the next argument as it's part of the option
		elif [[ ! ${!i} =~ ^-- ]]; then
			# Increment non-option argument count
			non_option_count=$((non_option_count+1))
			# Assume the first non-option argument after the subcommand is the leaf file
			if [[ $non_option_count -eq 1 ]]; then
				path_to_leaf_file=${!i}
			fi
		fi
	done

	if [[ -z $proof_file || -z $root_hash || -z $path_to_leaf_file || -L $path_to_leaf_file || -d $path_to_leaf_file || -L $proof_file || -d $proof_file || ! -f $proof_file || ! -f $path_to_leaf_file ]]; then
		usage
		exit 1
	fi

    if [[ ! $root_hash =~ ^[0-9A-F]+$ && ! $root_hash =~ ^[0-9a-f]+$ ]]; then
        usage
        exit 1
    fi

    verify_proof "$path_to_leaf_file" "$proof_file" "$root_hash"
fi

# if subcommand is not `build`, `gen-proof`, or `verify-proof` and options is not `-h` or `--help`
if [[ $1 != "build" && $1 != "gen-proof" && $1 != "verify-proof" && $1 != "-h" && $1 != "--help" ]]; then
    usage
    exit 1
fi