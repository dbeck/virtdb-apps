#!/bin/bash
cd sample/csv-provider
npm install
npm install ../../src/common/node-connector
node_modules/gulp/bin/gulp.js coffee
node_modules/gulp/bin/gulp.js
