#!/bin/bash

cd $HOME
git clone --recursive https://jenkins-starschema:Manager1@github.com/starschema/virtdb-apps.git virtdb-apps
echo Creating build $BUILDNO

echo >>$HOME/.netrc
echo machine github.com >>$HOME/.netrc
echo login jenkins-starschema >>$HOME/.netrc
echo password Manager1 >>$HOME/.netrc
echo >>$HOME/.netrc

cd $HOME/virtdb-apps

git config --global user.name "jenkins-starschema"
git config --global user.email jenkins@starschema.net

GPCONFIG_PATH="src/greenplum-config"
NODE_CONNECTOR_PATH="src/common/node-connector"

# -- make sure we have proto module built for us --
pushd src/common/proto
gyp --depth=. proto.gyp
make
popd

# -- figure out the next release number --
function release {
  echo "release"
  pushd $GPCONFIG_PATH
  VERSION=`npm version patch`
  git add package.json
  git commit -m "Increased version number to $VERSION"
  git tag $VERSION
  popd
  RELEASE_PATH="$HOME/build-result/virtdb-dbconfig-$VERSION"
  mkdir -p $RELEASE_PATH
  cp -R $GPCONFIG_PATH/* $RELEASE_PATH
  mkdir -p $RELEASE_PATH/lib
  pushd $RELEASE_PATH/..
  tar cvfj gpconfig-${VERSION}.tbz virtdb-dbconfig-$VERSION 
  popd
  echo $VERSION > version
  git push origin $VERSION
}

[[ ${1,,} == "release" ]] && RELEASE=true || RELEASE=false

echo "Building node-connector"
pushd $NODE_CONNECTOR_PATH
npm install
node_modules/gulp/bin/gulp.js build
popd

echo "Building greenplum-config"
pushd $GPCONFIG_PATH
npm install
echo "Node connector:"
ls ../common/node-connector
npm install ../common/node-connector
echo "virtdb-connector"
ls node_modules/virtdb-connector
node_modules/gulp/bin/gulp.js build
popd

[[ $RELEASE == true ]] && release || echo "non-release"

