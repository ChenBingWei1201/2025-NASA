#!/bin/bash

input=$1
answer=$2
output=$3

c=$(cat $input)
ab=($(cat $output))

if [[ ${ab[0]} -lt 1 || ${ab[0]} -gt 1000 ]]; then
    exit 1
fi

if [[ ${ab[1]} -lt 1 || ${ab[1]} -gt 1000 ]]; then
    exit 1
fi

if [[ $((${ab[0]} + ${ab[1]})) -ne ${c} ]]; then
    exit 1
fi

exit 0
