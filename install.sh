#!/bin/bash

PREFIX=$1
mkdir -p $PREFIX
cd $PREFIX
shift

if [[ $BASEBINS == true ]]; then 
    for compbin in $@; do
        echo "ln -s compiler_wrapper.sh $compbin"
        ln -s compiler_wrapper.sh $compbin
    done
elif [[ $PREFIX == *mpi ]]; then
    for mpibin in $@; do
        echo "ln -s ../compiler_wrapper.sh $mpibin"
        ln -s ../compiler_wrapper.sh $mpibin
    done
elif [[ $PREFIX == *llvm-amd ]]; then
    for llvmbin in $@; do
        echo "ln -s ../compiler_wrapper.sh $llvmbin"
        ln -s ../compiler_wrapper.sh $llvmbin
    done
else
    for compbin in $@; do
        if which $compbin >& /dev/null; then
            echo "ln -s compiler_wrapper.sh $compbin"
            ln -s compiler_wrapper.sh $compbin
        fi
    done
fi
