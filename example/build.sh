#!/usr/bin/bash
zig build-lib --main-pkg-path ../  ./mylib.zig
zig build-exe --main-pkg-path ../ -l mylib ./runmylib.zig
./runmylib
