#!/bin/sh

export BUILD_ROOT=$PWD
export PATH=$BUILD_ROOT/install/bin:$PATH

echo "-- gathering external dependencies"
echo 
git submodule update --init

echo "-- building node.js"
echo
cd 3rd-party/nodejs
./configure --prefix=$BUILD_ROOT/install >/dev/null 2>&1
make -j8 all
make install
cd $BUILD_ROOT

echo "-- bootstraping node-gyp"
echo 
npm install -g node-gyp

