#!/bin/bash
gyp --depth=. apps.gyp
make
out/Debug/diag-service tcp://config-service:65001 
