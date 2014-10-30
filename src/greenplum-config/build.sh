#!/bin/bash
GPCONFIG_PATH="src/greenplum-config"
NODE_CONNECTOR_PATH="src/common/node-connector"

function release {
  echo "release"
  pushd $GPCONFIG_PATH
  VERSION=`npm version patch`
  popd
  tar -czvf gpconfig-$VERSION.tar.gz -C $GPCONFIG_PATH .
}

function clear_connector {
  echo "clearining node connector"
  rm -rf $NODE_CONNECTOR_PATH/node_modules
  rm -rf $NODE_CONNECTOR_PATH/lib
}

function clear_greenplum_config {
  echo "Clearing greenplum config"
  rm -rf $GPCONFIG_PATH/node_modules
  rm -rf $GPCONFIG_PATH/out
}

[[ ${1,,} == "release" ]] && RELEASE=true || RELEASE=false

git submodule update --init --recursive
pushd src/common/proto
gyp --depth=. proto.gyp
make
popd

echo "Building node-connector"
[[ $RELEASE == true ]] && clear_connector
pushd $NODE_CONNECTOR_PATH
npm install
node_modules/gulp/bin/gulp.js build
popd

echo "Building greenplum-config"
pushd $GPCONFIG_PATH
[[ $RELEASE == true ]] && clear_greenplum_config 
npm install
echo "Node connector:"
ls ../common/node-connector
npm install ../common/node-connector
echo "virtdb-connector"
ls node_modules/virtdb-connector
node_modules/gulp/bin/gulp.js build
popd

[[ $RELEASE == true ]] && release || echo "non-release"
