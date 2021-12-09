#!/bin/bash

PREFIX=$1
cd $PREFIX
shift

if [[ $PREFIX == *mpi ]]; then
    for mpibin in $@; do
        echo "ln -s ../wrapper.sh $mpibin"
        ln -s ../wrapper.sh $mpibin
    done
else
    for compbin in $@; do
        if which $compbin >& /dev/null; then
            echo "ln -s wrapper.sh $compbin"
            ln -s wrapper.sh $compbin
        fi
    done
fi
