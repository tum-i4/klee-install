#!/bin/sh

########################################
# Read the command line argument
########################################

if [ "$#" -ne "1" ] || [ ! -d "$@" ] || [ ! "$(ls -A $DIR)" ]; then
    echo "ERROR: Installation needs an empty directory as a target"
    echo "usage: $0 /path/to/empty/dir"
    exit 1
fi

builddir=`realpath $1`
cd $builddir

########################################
# STEP 0: Check for all dependencies
########################################

required="
bc
bison
build-essential
cmake
curl
flex
git
libboost-all-dev
libcap-dev
libncurses5-dev
python-minimal
python-pip
subversion
unzip
zlib1g-dev
"

if lsb_release -a 2>> /dev/null | grep -q "Ubuntu"; then
    # if we are on Ubuntu

    error=0

    for pkg in $required
    # for all required packages
    do
        # Check, if this package is installed
        if ! dpkg -l $pkg >> /dev/null 2>&1; then
            echo "Error: $pkg is not installed"
            error=1
        fi
    done

    if [ $error -eq 1 ]; then
        echo "STOP: Not all dependencies installed"
        exit 1
    fi
fi

########################################
# STEP 1: LLVM
########################################

svn co https://llvm.org/svn/llvm-project/llvm/tags/RELEASE_342/final llvm
svn co https://llvm.org/svn/llvm-project/cfe/tags/RELEASE_342/final llvm/tools/clang
svn co https://llvm.org/svn/llvm-project/compiler-rt/tags/RELEASE_342/final llvm/projects/compiler-rt
svn co https://llvm.org/svn/llvm-project/libcxx/tags/RELEASE_342/final llvm/projects/libcxx
svn co https://llvm.org/svn/llvm-project/test-suite/tags/RELEASE_342/final/ llvm/projects/test-suite

rm -rf llvm/.svn
rm -rf llvm/tools/clang/.svn
rm -rf llvm/projects/compiler-rt/.svn
rm -rf llvm/projects/libcxx/.svn
rm -rf llvm/projects/test-suite/.svn

cd llvm
./configure --enable-optimized --disable-assertions --enable-targets=host --with-python="/usr/bin/python2"
make -j `nproc`

make -j `nproc` check-all
cd ..

########################################
# STEP 2: Minisat
########################################

git clone --depth 1 https://github.com/stp/minisat.git
# Commit ID: 37dc6c67e2af26379d88ce349eb9c4c6160e8543 (more than 2 years old)
rm -rf minisat/.git

cd minisat
make
cd ..

########################################
# STEP 3: STP
########################################

git clone --depth 1 --branch 2.1.2 https://github.com/stp/stp.git
rm -rf stp/.git

cd stp
mkdir build
cd build
cmake \
 -DBUILD_SHARED_LIBS:BOOL=OFF \
 -DENABLE_PYTHON_INTERFACE:BOOL=OFF \
 -DMINISAT_INCLUDE_DIR="../../minisat/" \
 -DMINISAT_LIBRARY="../../minisat/build/release/lib/libminisat.a" \
 -DCMAKE_BUILD_TYPE="Release" \
 -DTUNE_NATIVE:BOOL=ON ..
make -j `nproc`
cd ../..

########################################
# STEP 4: uclibc and the POSIX environment model
########################################

git clone --depth 1 --branch klee_uclibc_v1.0.0 https://github.com/klee/klee-uclibc.git
rm -rf klee-uclibc/.git

cd klee-uclibc
./configure \
 --make-llvm-lib \
 --with-llvm-config="../llvm/Release/bin/llvm-config" \
 --with-cc="../llvm/Release/bin/clang"
make -j `nproc`
cd ..

########################################
# STEP 5: Z3
########################################

git clone --depth 1 --branch z3-4.4.1 https://github.com/Z3Prover/z3.git
rm -rf z3/.git

cd z3
python scripts/mk_make.py
cd build
make -j `nproc`

# partialy copied from make install target
mkdir -p ./include
mkdir -p ./lib
cp ../src/api/z3.h ./include/z3.h
cp ../src/api/z3_v1.h ./include/z3_v1.h
cp ../src/api/z3_macros.h ./include/z3_macros.h
cp ../src/api/z3_api.h ./include/z3_api.h
cp ../src/api/z3_algebraic.h ./include/z3_algebraic.h
cp ../src/api/z3_polynomial.h ./include/z3_polynomial.h
cp ../src/api/z3_rcf.h ./include/z3_rcf.h
cp ../src/api/z3_interp.h ./include/z3_interp.h
cp ../src/api/z3_fpa.h ./include/z3_fpa.h
cp libz3.so ./lib/libz3.so
cp ../src/api/c++/z3++.h ./include/z3++.h

cd ../..

########################################
# STEP 6: KLEE
########################################

git clone --depth 1 --branch v1.2.0 https://github.com/klee/klee.git
rm -rf klee/.git

cd klee
./configure \
 LDFLAGS="-L$builddir/minisat/build/release/lib/" \
 --with-llvm=$builddir/llvm/ \
 --with-llvmcc=$builddir/llvm/Release/bin/clang \
 --with-llvmcxx=$builddir/llvm/Release/bin/clang++ \
 --with-stp=$builddir/stp/build/ \
 --with-uclibc=$builddir/klee-uclibc \
 --with-z3=$builddir/z3/build/ \
 --enable-posix-runtime

make -j `nproc` ENABLE_OPTIMIZED=1

# Copy Z3 libraries to a place, where klee can find them
cp ../z3/build/lib/libz3.so ./Release+Asserts/lib/

make -j `nproc` check

cd ..

########################################
# Build complete
########################################

echo ""
echo "Congratulations. $builddir is initialized completely"
