#!/bin/bash

gyp --depth=. apps.gyp
make

echo "Building node-connector"
pushd src/common/node-connector
npm install --loglevel error
node_modules/gulp/bin/gulp.js --silent build
popd

echo "Building greenplum-config"
pushd src/greenplum-config
npm install --loglevel error
npm install --loglevel error ../common/node-connector
node_modules/gulp/bin/gulp.js --silent build
popd
