#!/bin/bash
gyp --depth=. apps.gyp
make
out/Debug/config-service tcp://0.0.0.0:65001
