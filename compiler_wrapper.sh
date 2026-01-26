#!/bin/bash

# Determine basename and path of call
mypath="$( cd "$(dirname "$0")" ; pwd )"
myname=${0##*/}
myparent=$(ps -o comm= $PPID)
envbin=$(which $myname)

# Remove current instance of wrapper from PATH, if set
if cmp --silent $envbin $mypath/$myname; then
    if [[ $mypath == *llvm-amd ]]; then
        if [[ -n $NCAR_WRAPPER_LLVM_AMD ]]; then
            newpath=${PATH/${envbin%/*}:/${NCAR_WRAPPER_LLVM_AMD}:}
        else
            >&2 echo "NCAR_ERROR: hip wrapper used but NCAR_WRAPPER_LLVM_AMD not set"
            exit 1
        fi
    else
        newpath=${PATH/${envbin%/*}:}
    fi

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

# Function to collect module settings from environment
function get_module_flags {
    vartype=$1 prefix=$2 rawlist="$3" varlist=
    [[ ${rawlist}z == z ]] && return
    varlist=$rawlist

    for var in $varlist; do
        margs[$vartype]="${prefix}${!var} ${margs[$vartype]}"
    done
}

# Skip wrapper if:
# - It has already been called
# - If it's called by a Cray wrapper
# - It has been called by golang
if [[ $NCAR_WRAPPER_ACTIVE == true ]]           \
    || [[ " cc CC ftn " == *" $myparent "* ]]   \
    || [[ -n ${!CGO_*} ]]; then
    check_binary $myname

    # Preserve quotes from input arguments
    for arg in "$@"; do
        inargs+=("$arg")
    done

    $myname "${inargs[@]}"
else
    # If Cray wrappers are being used, convert names to Cray...
    if [[ -n $CRAYPE_DIR ]] && [[ ${NCAR_WRAPPER_CRAY,,} != false ]]; then
        case $myname in
            icc|icpc|ifort)
                export INTEL_COMPILER_TYPE=CLASSIC
                ;;&
            icx|icpx|ifx)
                export INTEL_COMPILER_TYPE=ONEAPI
                ;;&
            icc|icx|pgcc|nvc|craycc|clang)
                myname=cc
                ;;
            icpc|icpx|pgc++|nvc++|crayCC|craycxx|clang++)
                myname=CC
                ;;
            ifort|ifx|pgf77|pgf90|pgf95|pgfortran|nvfortran|crayftn|flang)
                myname=ftn
                ;;
            gcc)
                if [[ $PE_ENV == GNU ]]; then
                    myname=cc
                fi
                ;;
            g++)
                if [[ $PE_ENV == GNU ]]; then
                    myname=CC
                fi
                ;;
            gfortran)
                if [[ $PE_ENV == GNU ]]; then
                    myname=ftn
                fi
                ;;
            *)
                if [[ -n $CRAY_MPICH_DIR ]]; then
                    case $myname in
                        mpicc)
                            myname=cc
                            ;;
                        mpic++|mpicxx)
                            myname=CC
                            ;;
                        mpif77|mpif90|mpifort)
                            myname=ftn
                            ;;
                    esac
                fi
                ;;
        esac
    fi

    check_binary $myname

    # Associative storage for variables
    declare -A margs

    if [[ " $@ " != *" -help "* ]]; then
        # Get any modifier flags that must go first
        mflags_compiler=NCAR_MFLAGS_${LMOD_FAMILY_COMPILER^^}
        margs[MFLAGS]="${!mflags_compiler} $NCAR_MFLAGS_GENERIC"

        # These flags are optionally added based on other settings to assist
        # in tasks like debugging and profiling
        if [[ -n $NCAR_WRAPPER_MFLAGS_DEBUG ]]; then
            margs[MFLAGS]="${margs[MFLAGS]} $NCAR_MFLAGS_DEBUG"
        elif [[ -n $NCAR_WRAPPER_MFLAGS_PROFILE ]]; then
            if [[ $LMOD_FAMILY_COMPILER == cce ]]; then
                case $myname in
                    crayftn|ftn|mpif90)
                        margs[MFLAGS]="${margs[MFLAGS]} $NCAR_MFLAGS_PROFILE_FORTRAN"
                        ;;
                    *)
                        margs[MFLAGS]="${margs[MFLAGS]} $NCAR_MFLAGS_PROFILE_C"
                        ;;
                esac
            else
                margs[MFLAGS]="${margs[MFLAGS]} $NCAR_MFLAGS_PROFILE"
            fi

            if [[ -n $NCAR_ROOT_LINARO_FORGE ]] && [[ -n $CRAY_MPICH_DIR ]]; then
                map_wrapper_check=true
                map_wrapper_dir=$HOME/.map_wrappers/$NCAR_VERSION_LINARO_FORGE/mpich-$LMOD_FAMILY_MPI_VERSION/$LMOD_FAMILY_COMPILER/$LMOD_FAMILY_COMPILER_VERSION
                margs[LDFLAGS]="-L$map_wrapper_dir -Wl,--eh-frame-hdr -Wl,-rpath,$map_wrapper_dir"
                margs[LIBS]="-lmap-sampler-pmpi -lmap-sampler -ldl"
            fi
        fi  

        # Add headers to compile line
        get_module_flags INC -I "${!NCAR_INC_*}"

        if [[ " $@ " != *" -c "* ]]; then
            # Add library paths to link line
            get_module_flags LDFLAGS -Wl,-rpath, "${!NCAR_LDFLAGS_*}"
            get_module_flags LDFLAGS -L "${!NCAR_LDFLAGS_*}"

            # Make sure RPATHs are respected by newer ldd
            margs[LDFLAGS]="-Wl,--disable-new-dtags ${margs[LDFLAGS]}"

            # Add library flags if desired
            if [[ -z ${NCAR_EXCLUDE_LIBS+x} ]]; then
                get_module_flags LIBS "" "${!NCAR_LIBS_*}"
            fi

            # Only add as-needed flag if we configure this behavior
            if [[ -n $NCAR_USE_ASNEEDED ]]; then
                margs[LIBS]="-Wl,--as-needed ${margs[LIBS]}"
            fi
        fi
    fi

    # Process arguments and preserve "user" arg formatting
    userargs=()

    if [[ -n $NCAR_WRAPPER_INTEL_CHECK ]]; then
        for arg in "$@"; do
            case "$arg" in
                --ncar-debug-include)
                    echo ${margs[INC]}
                    exit 0
                    ;;
                --ncar-debug-libraries)
                    echo ${margs[LIBS]} ${margs[LDFLAGS]}
                    exit 0
                    ;;
                --ncar-print-opts)
                    show=true
                    ;;
                *)
                    if [[ " ${margs[LIBS]} " != *" $arg "* ]]; then
                        if [[ $arg == -x* ]] || [[ $arg == -ax* ]]; then
                            intel_flag_warning=true
                        fi

                        userargs+=("$arg")
                    fi
                    ;;
            esac
        done

        if [[ $intel_flag_warning == true ]]; then
            >&2 echo "NCAR_WARN: Intel -x/-ax options hurt performance on AMD CPUs! Use -march instead."
        fi
    else
        for arg in "$@"; do
            case "$arg" in
                --ncar-debug-include)
                    echo ${margs[INC]}
                    exit 0
                    ;;
                --ncar-debug-libraries)
                    echo ${margs[LIBS]} ${margs[LDFLAGS]}
                    exit 0
                    ;;
                --ncar-debug-executable)
                    echo $(which $myname)
                    exit 0
                    ;;
                --ncar-print-opts)
                    show=true
                    ;;
                *)
                    if [[ " ${margs[LIBS]} " != *" $arg "* ]]; then
                        userargs+=("$arg")
                    fi
                    ;;
            esac
        done

    fi

    # Call command with module and user args
    if [[ $show == true ]]; then
        if [[ $NCAR_WRAPPER_PREPEND_RPATH == true ]]; then
            echo "$(which $myname) ${margs[MFLAGS]} ${margs[LDFLAGS]} ${userargs[@]} ${margs[INC]} ${margs[LIBS]}"
        else
            echo "$(which $myname) ${margs[MFLAGS]} ${userargs[@]} ${margs[INC]} ${margs[LIBS]} ${margs[LDFLAGS]}"
        fi
    else
        export NCAR_WRAPPER_ACTIVE=true

        if [[ $map_wrapper_check == true ]]; then
            if [[ ${NCAR_WRAPPER_MAP_GENERATE:-true} == true ]]; then
                if [[ ! -e $map_wrapper_dir/libmap-sampler.so ]]; then
                    >&2 echo "NCAR_INFO: Creating shared sampler library for Forge MAP (NCAR_WRAPPER_MAP_GENERATE=false to disable)."
                    mkdir -p $map_wrapper_dir
                    make-profiler-libraries --platform=cray --lib-type=shared --quiet $map_wrapper_dir
                fi
            fi
        fi

        if [[ $NCAR_WRAPPER_PREPEND_RPATH == true ]]; then
            $myname ${margs[MFLAGS]} ${margs[LDFLAGS]} "${userargs[@]}" ${margs[INC]} ${margs[LIBS]}
        else
            $myname ${margs[MFLAGS]} "${userargs[@]}" ${margs[INC]} ${margs[LIBS]} ${margs[LDFLAGS]}
        fi
    fi
fi
