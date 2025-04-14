#!/usr/bin/env bash

## Comand line args ############################################################

fnames=()
patterns=()
verbose=0
show_help=0

while [ $# -gt 0 ]
do
    case "$1" in
        -k|--pattern)
            patterns+=($2)
            shift
            ;;
        -v|--verbose)
            verbose="1"
            ;;
        -vv)
            verbose="2"
            ;;
        -h|--help)
            show_help=1
            ;;
        *)
            if [ $show_help -eq 0 ]; then
                fnames+=("$1")
            fi
            fnames+=($1)
            ;;
    esac
    shift
done

# Display help information if --help is used
if [ $show_help -eq 1 ]; then
    echo "Usage: $0 [options] [files]"
    echo ""
    echo "Options:"
    echo "  -k, --pattern <PATTERN>   Specify test patterns"
    echo "  -v, --verbose            Enable verbose output (can be used twice for more detail)"
    echo "  --help                   Show this help message"
    exit 0
fi

# If no fnames given, use all test files under the current directory
if [ ${#fnames[@]} -eq 0 ]
then
    fnames=($(find ./tests -name "test_*.sh"))
fi

## Helpers #####################################################################

#----
# Determine if a given function should be run
#
# @param func_name: The name of the function to check
#----
function should_run {
    local func_name=$1
    if [ ${#patterns[@]} -eq 0 ]
    then
        return 0
    fi
    for pattern in "${patterns[@]}"
    do
        if [[ $func_name == *"$pattern"* ]]
        then
            return 0
        fi
    done
    return 1
}

# Function definition for fail
function fail {
  # Capture the current line number
  local LINE_NUMBER=${BASH_SOURCE[1]}

  # Print failure message with line number
  echo "Error in $LINE_NUMBER" >&2
  exit 1
}


## Main ########################################################################

failing_tests=""
failure_output=""
for fname in "${fnames[@]}"
do
    # Find all test functions defined in the given file
    test_funcs=($(grep --color=never -oE '^\s*function\s+(test_[^ ]+)' $fname | grep --color=never -oE 'test_.*'))
    if [ "$verbose" == "2" ]
    then
        echo "$fname"
    fi

    if ! [ ${#test_funcs[@]} -eq 0 ]
    then
        echo -n "$fname "
        source $fname
        for funcname in "${test_funcs[@]}"
        do
            if should_run "$funcname"
            then
                scoped_funcname="$fname:$funcname"
                if [ "$verbose" == "2" ]
                then
                    echo "RUNNING $scoped_funcname"
                    $funcname
                    result="$?"
                    output=""
                else
                    output=$($funcname 2>&1)
                    result="$?"
                fi
                if [ "$result" == "0" ]
                then
                    echo -n "$(tput setaf 2).$(tput sgr0)"
                else
                    if [ "$failing_tests" == "" ]
                    then
                        failing_tests="$scoped_funcname"
                    else
                        failing_tests="$failing_tests $scoped_funcname"
                    fi
                    failure_output="${failure_output}\n\n---------\n$scoped_funcname\n\n$output"
                    echo -n "$(tput setaf 1)F$(tput sgr0)"
                fi
            fi
        done
        echo
    fi
done

# Report the final results
echo ""
if [ "${failing_tests}" != "" ]
then
    echo "$(tput setaf 1)FAILED$(tput sgr0)"
    if [ "$verbose" == "1" ]
    then
        echo -e "$failure_output"
    fi
    for failing_test in "${failing_tests}"
    do
        echo "$(tput setaf 1)${failing_test}$(tput sgr0)"
    done
    exit 1
else
    echo "$(tput setaf 2)PASSED$(tput sgr0)"
fi