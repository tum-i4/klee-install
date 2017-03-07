#!/bin/sh

########################################
# Read the command line argument
########################################

if [ "$#" -ne "1" ]; then
    echo "ERROR: No target directory was given!"
    echo "usage: $0 /path/to/empty/dir"
    exit 1
fi

README="$(dirname "$(realpath "$0")")/README.md"
BUILDDIR="$(realpath "$1")"

if [ ! -d "$BUILDDIR" ] || [ ! -z "$(ls -A "$BUILDDIR")" ]; then
    echo "ERROR: Installation needs an empty directory as a target!"
    echo "usage: $0 /path/to/empty/dir"
    exit 1
fi

cd "$BUILDDIR" || exit

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
        if ! dpkg -l "$pkg" >> /dev/null 2>&1; then
            echo "Error: $pkg is not installed"
            error=1
        fi
    done

    if [ $error -eq 1 ]; then
        echo "STOP: Not all dependencies installed"
        exit 1
    fi
fi

# This extracts all commands from the README.md and executes them
eval "$( \
# Extract all relevant build steps -> Step 1 until 6, excluding 7
sed -n '/## Step 1: LLVM/,/## Step 7: Link some executables/p' "$README" | \
# Extract all marked code snippets
sed -n '/```/,/```/p' | grep -v '```' | \
# Remove comments and the automatic assignment of BUILDDIR and empty lines
grep -v '^#' | grep -v '^BUILDDIR=' | awk 'NF > 0' \
)"

echo ""
echo "Congratulations. $BUILDDIR is initialized completely"
