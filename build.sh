#!/bin/sh

export BUILD_ROOT=$PWD

echo "-- gathering external dependencies"
echo 
git submodule update --init

echo "-- building gtest"
echo
cd 3rd-party/gtest-1.7.0
./configure >/dev/null 2>&1
make all
# 3rd-party/gtest-1.7.0/scripts/gtest-config
export GTEST_LIBDIR=$PWD/lib
export GTEST_INCLUDEDIR=$PWD/include
cd $BUILD_ROOT

echo "-- building node.js"
echo
cd 3rd-party/nodejs
./configure --prefix=$BUILD_ROOT >/dev/null 2>&1
make all install
cd $BUILD_ROOT


