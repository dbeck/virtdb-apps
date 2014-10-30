#!/bin/bash

gyp --depth=. apps.gyp
make

echo "Building node-connector"
pushd src/common/node-connector
npm install
node_modules/gulp/bin/gulp.js build
popd

echo "Building greenplum-config"
pushd src/greenplum-config
npm install
npm install ../common/node-connector
node_modules/gulp/bin/gulp.js build
popd
