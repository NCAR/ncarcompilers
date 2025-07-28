PREFIX ?= /usr/local

abin = gcc cc CC ftn
lbin = clang clang++ flang
cbin = gfortran g++ c++ icc ifort icpc icx ifx icpx pgcc pgf77 pgf90 pgf95 pgfortran pgc++ nvc nvc++ nvfortran crayCC craycc craycxx crayftn $(lbin)
mbin = mpicc mpiCC mpigcc mpiicc mpiifort mpifort mpif77 mpif90 mpif08 mpic++ mpicxx ortecc orteCC

.PHONY: all mpi hip install clean

all:
	BASEBINS=true ./install.sh bin $(abin)
	./install.sh bin $(cbin)
	cp compiler_wrapper.sh bin

mpi:
	./install.sh bin/mpi $(mbin)

hip:
	./install.sh bin/llvm-amd $(lbin)
	mkdir -p bin/hip
	cp hipcc_wrapper.sh bin/hip/hipcc

install:
	mkdir -p $(PREFIX)
	cp -r bin $(PREFIX)

clean:
	rm -r bin
