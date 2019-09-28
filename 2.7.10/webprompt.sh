#!/bin/bash -ex

# Simple Python prompt for the browser, for smoke testing

# Copyright (C) 2019  Sylvain Beucler

# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Alternatively: use Emscripten's old binary:
# emscripten/tests/python/python.bc -s ERROR_ON_UNDEFINED_SYMBOLS=0

INSTALLDIR=${INSTALLDIR:-$(dirname $(readlink -f $0))/destdir}
BUILD=t

mkdir -p $BUILD

cython ../emscripten.pyx -o $BUILD/emscripten.c
emcc $BUILD/emscripten.c -o $BUILD/emscripten.bc -I $INSTALLDIR/include/python2.7
emcc -o $BUILD/webprompt.html \
  webprompt-main.c $BUILD/emscripten.c \
  -I$INSTALLDIR/include/python2.7 -L$INSTALLDIR/lib -lpython2.7 \
  -s EMULATE_FUNCTION_POINTER_CASTS=1 \
  -s USE_ZLIB=1 \
  -s TOTAL_MEMORY=256MB \
  --preload-file $INSTALLDIR/lib/python2.7@/lib/python2.7 \
  --shell-file webprompt-shell.html \
  -s EXPORTED_FUNCTIONS="['_main', '_malloc', '_Py_Initialize', '_PyRun_SimpleString']" \
  -s EXTRA_EXPORTED_RUNTIME_METHODS='["ccall", "cwrap"]'
