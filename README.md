# How to build KLEE

This is a repository for all my notes about the installation of [KLEE](https://klee.github.io/). This README.md contains a step by step manual for building KLEE with all its dependencies. Additionally, I wrote a small script for ubuntu, that automatically executes all the commands listed here. If you build KLEE for the first time, I strongly recommend executing the commands manually, but if you end up doing it again, just save your time with the script.

----------

# Manual build step by step

## Introduction

There are a ton of installation instructions for [KLEE](https://klee.github.io/) out there in the web. This is yet another manual, but it tries to be a little different. First of all, it is not Ubuntu specific. It works on Ubuntu, but it also works on other distros like Arch Linux. Furthermore, this setup do not use the sudo command or any kind of installation. You get a pure local build directory full of all the necessary tools and nothing else. Thereby, you can have multiple klee versions and setups on the same machine. In order to uninstall these tools, simply remove the directory, where they have been built in.

### The resulting directory structure:
```
build
├── klee
├── klee-uclibc
├── llvm
├── minisat
├── stp
└── z3
```

I prefer having my self-compiled binaries in a build-folder inside my home directory, but you are free to place it wherever you want. Just create an empty directory anywhere in your system, remember its path and name, and execute all the following commands inside this directory.

### storage-usage

The whole files, that are needed during the build process, needs at least 2 GB of storage. This manual uses version control systems (git, svn) to download the source files. Thereby each file is stored twice: in the version control and in the checkout-folder. The version control is not really useful or necessary for non-developers of these tools, so this manual removes these files with commands like `rm -rf {.git,.svn}`. You can leave this commands out, but remember, that this will likely double the amount of storage to at least 4 GB in total.


## Usefull Links:

* [The official (but buggy) installation manual](https://klee.github.io/build-llvm34/)
* [Build LLVM on your own](http://www.llvm.org/docs/GettingStarted.html#getting-started-quickly-a-summary)
* [The old official installation manual](https://llvm.org/svn/llvm-project/klee/trunk/www/GetStarted.html?p=156062)
* [More recent user installation for Ubuntu 14.04 LTS](http://blog.opensecurityresearch.com/2014/07/klee-on-ubuntu-1404-lts-64bit.html)
* [STP installation manual with build options](https://github.com/stp/stp/blob/master/INSTALL.md)
* [metaSMT-Support for KLEE](http://srg.doc.ic.ac.uk/projects/klee-multisolver/getting-started.html)


## Step 0: Install required tools for the build

### Ubuntu (16.04)
```
sudo apt-get install bc bison build-essential cmake curl flex git libboost-all-dev libcap-dev libncurses5-dev python-minimal python-pip subversion unzip zlib1g-dev
```
### Arch Linux
```
sudo pacman -S bc bison boost cmake curl flex gcc git libcap ncurses python python2 python2-pip subversion zlib
```


## Step 1: LLVM

### Checkout sourcecode of the core and relevant projects
```
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
```

### Build the binaries

The llvm-testsuite, that is used later for `make check-all` needs a python2. Maybe the default on your system is python3. So you have to add the `--with-python`-option with your path to a python2 executable.

```
cd llvm
./configure --enable-optimized --disable-assertions --enable-targets=host --with-python="/usr/bin/python2"
make -j `nproc`

make -j `nproc` check-all
cd ..
```

## Step 2: Minisat

```
git clone --depth 1 https://github.com/stp/minisat.git
# Commit ID: 3db58943b6ffe855d3b8c9a959300d9a148ab554 (very old - from Jun 22, 2015)
rm -rf minisat/.git

cd minisat
make
cd ..
```


## Step 3: STP

```
git clone --depth 1 --branch stp-2.2.0 https://github.com/stp/stp.git
rm -rf stp/.git

cd stp
mkdir build
cd build
cmake \
 -DBUILD_STATIC_BIN=ON \
 -DBUILD_SHARED_LIBS:BOOL=OFF \
 -DENABLE_PYTHON_INTERFACE:BOOL=OFF \
 -DMINISAT_INCLUDE_DIR="../../minisat/" \
 -DMINISAT_LIBRARY="../../minisat/build/release/lib/libminisat.a" \
 -DCMAKE_BUILD_TYPE="Release" \
 -DTUNE_NATIVE:BOOL=ON ..
make -j `nproc`
cd ../..
```

## Step 4: uclibc and the POSIX environment model
```
git clone --depth 1 --branch klee_uclibc_v1.0.0 https://github.com/klee/klee-uclibc.git
rm -rf klee-uclibc/.git

cd klee-uclibc
./configure \
 --make-llvm-lib \
 --with-llvm-config="../llvm/Release/bin/llvm-config" \
 --with-cc="../llvm/Release/bin/clang"
make -j `nproc`
cd ..
```

## Step 5: Z3
```
git clone --depth 1 --branch z3-4.5.0 https://github.com/Z3Prover/z3.git
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
cp ../src/api/z3_ast_containers.h ./include/z3_ast_containers.h
cp ../src/api/z3_algebraic.h ./include/z3_algebraic.h
cp ../src/api/z3_polynomial.h ./include/z3_polynomial.h
cp ../src/api/z3_rcf.h ./include/z3_rcf.h
cp ../src/api/z3_fixedpoint.h ./include/z3_fixedpoint.h
cp ../src/api/z3_optimization.h ./include/z3_optimization.h
cp ../src/api/z3_interp.h ./include/z3_interp.h
cp ../src/api/z3_fpa.h ./include/z3_fpa.h
cp libz3.so ./lib/libz3.so
cp ../src/api/c++/z3++.h ./include/z3++.h

cd ../..
```

## Step 6: KLEE

This is the only step in this manual, where we need the absolute path in the commands. The trick with the custom shell variable should solve it correctly. Nevertheless, if the configure command fails, try it again with explicit paths.

```
git clone --depth 1 --branch v1.3.0 https://github.com/klee/klee.git
rm -rf klee/.git

BUILDDIR=`pwd`
cd klee
./configure \
 LDFLAGS="-L$BUILDDIR/minisat/build/release/lib/" \
 --with-llvm=$BUILDDIR/llvm/ \
 --with-llvmcc=$BUILDDIR/llvm/Release/bin/clang \
 --with-llvmcxx=$BUILDDIR/llvm/Release/bin/clang++ \
 --with-stp=$BUILDDIR/stp/build/ \
 --with-uclibc=$BUILDDIR/klee-uclibc \
 --with-z3=$BUILDDIR/z3/build/ \
 --enable-posix-runtime

make -j `nproc` ENABLE_OPTIMIZED=1

# Copy Z3 libraries to a place, where klee can find them
cp ../z3/build/lib/libz3.so ./Release+Asserts/lib/

make -j `nproc` check
cd ..
```

A small note: I have tried this setup on several systems and this last check has never finished without errors. I am not absolutely sure, if this is normal or not. From my experience around 4 up to 9 failing test cases seems to be normal, if everything seems to work.

## Step 7: Link some executables

This step is completely optional, but if you have to execute the generated programs again and again, it is helpful to have smaller shortcuts for them. For this purpose all modern shells offers some way of creating `alias`-commands.

Put these lines at the end of your `~/.bashrc` (if using bash) or `~/.zshrc` (if using zsh). If you don't use a build-directory in your home folder, just replace the paths corresponding to your directory structure. To separate the self-build versions from the system ones, I add the prefix "my" to the alias commands, but you can name them what ever you want.

```
alias       myklee="~/build/klee/Release+Asserts/bin/klee"
alias myktest-tool="~/build/klee/Release+Asserts/bin/ktest-tool"
alias      myclang="~/build/llvm/Release/bin/clang"
alias        mylli="~/build/llvm/Release/bin/lli"
alias   myllvm-dis="~/build/llvm/Release/bin/llvm-dis"
```

These are definitely not all the binaries created by this manual, but at least the most common ones. Nevertheless, I assume you see the pattern and of course you can add, whatever you find helpful.

## Solutions for common errors

### During the ./configure command of KLEE

```
checking for vc_setInterfaceFlags in -lstp... no
Could not link with libstp
checking for vc_setInterfaceFlags in -lstp... no
configure: error: Unable to link with libstp. Check config.log to see what went wrong
```
and in the corresponding config.log
```
configure:5121: checking for vc_setInterfaceFlags in -lstp
configure:5146: g++ -o conftest -g -O2   conftest.cpp -lstp -L.../stp/build/lib -lminisat   >&5
.../stp/build/lib/libstp.a(RunTimes.cpp.o): In function `RunTimes::getDifference[abi:cxx11]()':
.../stp/build/../lib/AST/RunTimes.cpp:118: undefined reference to `Minisat::memUsed()'
...
```

In other words, the compiler cannot find a lot of minisat functions. This problem is caused by the shared library for minisat, that must be added and must be found during the compilation process. Make sure, that you are giving the correct path to minisat in the LDFLAGS. See step 6 for details.

### During runs of KLEE

```
.../bin/klee: error while loading shared libraries: libz3.so: cannot open shared object file: No such file or directory
```

KLEE cannot find the libz3.so library of Z3. The easiest solution is to directly copy the library to the lib directory of KLEE. See step 6 for details.

----------

```
error while loading shared libraries: libkleeRuntest.so.1.0: cannot open shared object file: No such file or directory
```
Somehow, KLEE searches a specific version of its shared library and its Makefile just generates a generic one. To solve this error, just create a symbolic link to the generic library as the specific version required.
```
ln -s ~/build/klee/Release+Asserts/lib/libkleeRuntest.so ~/build/klee/Release+Asserts/lib/libkleeRuntest.so.1.0
```
