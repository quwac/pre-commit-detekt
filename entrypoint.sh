#!/bin/bash

set -eu

# parse arguments
opts=()
filenames=""
filenames_started=0
input_included=0
for i in "$@"; do
    if [ "$i" == "--input" ] || [ "$i" == "-i" ]; then
        input_included=1
    fi

    if [ $filenames_started -eq 0 ]; then
        if [[ ${i} == *.kt ]] || [[ ${i} == *.kts ]]; then
            filenames_started=1
        fi
    fi

    if [ $filenames_started -eq 1 ]; then
        if [ "$filenames" != "" ]; then
            filenames="$filenames,"
        fi
        filenames="${filenames}${i}"
    else
        opts+=("$i")
    fi
done

# run detekt
if [ "$filenames" == "" ] || [[ $input_included -eq 1 ]]; then
    java -jar "/opt/detekt/detekt-cli-all.jar" "${opts[@]}"
else
    java -jar "/opt/detekt/detekt-cli-all.jar" "${opts[@]}" --input "$filenames"
fi