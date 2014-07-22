#!/bin/sh

export BUILD_ROOT=$PWD
export PATH=$BUILD_ROOT/bin:$PATH

echo "-- gathering external dependencies"
echo 
git submodule update --init

echo "-- building node.js"
echo
cd 3rd-party/nodejs
./configure --prefix=$BUILD_ROOT >/dev/null 2>&1
make all install
cd $BUILD_ROOT

echo "-- bootstraping node-gyp"
echo 
npm install node-gyp

