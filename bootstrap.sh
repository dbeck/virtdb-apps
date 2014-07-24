#!/bin/sh

export BUILD_ROOT=$PWD
export PATH=$BUILD_ROOT/install/bin:$PATH

echo "-- gathering external dependencies"
echo
git submodule update --init --remote

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
npm install -g gulp
npm install -g gulp-coffee

echo "-- bootstraping gyp"
echo
export PATH=$BUILD_ROOT/install/lib/node_modules/node-gyp/gyp:$PATH
export GYP=$BUILD_ROOT/install/lib/node_modules/node-gyp/gyp/gyp
if [ -e $GYP ]
then
  echo $GYP
else
  echo NO SUCH FILE: $GYP
  exit 100
fi

gyp --depth=. main.gyp
