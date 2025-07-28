#!/bin/bash

# Determine basename and path of call
mypath="$( cd "$(dirname "$0")" ; pwd )"
myname=hipcc
myparent=$(ps -o comm= $PPID)
envbin=$(which $myname)

# Remove current instance of wrapper from PATH, if set
if cmp --silent $envbin $mypath/$myname; then
    newpath=${PATH/${envbin%/*}:}

    if [[ $newpath == $PATH ]]; then
        >&2 echo "NCAR_ERROR: cannot remove wrapper from path"
        exit 1
    else
        export PATH=$newpath
    fi
fi

# Check for existence of actual binary
function check_binary {
    if ! which $1 >& /dev/null; then
        >&2 echo "NCAR_ERROR: wrapper cannot locate path to $1"
        exit 1
    fi
}

check_binary $myname

if [[ " $@ " == *" --ncar-debug-hipcc "* ]]; then
    echo "Real hipcc     = $(which hipcc)"
    echo "HIP_CLANG_PATH = $NCAR_WRAPPER_LLVM_AMD"
    exit 0
fi

HIP_CLANG_PATH=$NCAR_WRAPPER_HIP_CLANG hipcc "$@"
