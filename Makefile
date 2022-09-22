PREFIX ?= /usr/local

abin = gcc cc CC ftn
cbin = gfortran g++ c++ icc ifort icpc icx ifx icpx pgcc pgf77 pgf90 pgf95 pgfortran pgc++ nvc nvc++ nvfortran crayCC craycc craycxx crayftn
mbin = mpicc mpiCC mpigcc mpiicc mpiifort mpifort mpif77 mpif90 mpif08 mpic++ mpicxx ortecc orteCC

.PHONY: all wrapper install clean

all: wrapper
	./install.sh bin $(cbin)
	./install.sh bin/mpi $(mbin)

wrapper:
	mkdir -p bin/mpi
	cp wrapper.sh bin
	BASEBINS=true ./install.sh bin $(abin)

install:
	mkdir -p $(PREFIX)
	cp -r bin $(PREFIX)

clean:
	rm -r bin
