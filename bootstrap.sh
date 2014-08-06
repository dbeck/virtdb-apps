#!/bin/sh

export BUILD_ROOT=$PWD
export PATH=$BUILD_ROOT/install/bin:$PATH

echo "-- gathering external dependencies"
echo
git submodule update --init --remote --recursive

echo "-- building node.js"
echo
cd src/node
./configure --prefix=$BUILD_ROOT/install >/dev/null 2>&1
make -j8 all
make install
cd $BUILD_ROOT

echo "-- bootstraping node-gyp, gulp"
echo
npm install node-gyp
npm install gulp
npm install gulp-coffee
npm install zmq
npm install protobuf
npm install node-protobuf

echo "-- bootstraping gyp"
echo
export PATH=$BUILD_ROOT/node_modules/node-gyp/gyp:$PATH
export GYP=$BUILD_ROOT/node_modules/node-gyp/gyp/gyp
if [ -e $GYP ]
then
  echo $GYP
else
  echo NO SUCH FILE: $GYP
  exit 100
fi

$GYP --depth=. apps.gyp
