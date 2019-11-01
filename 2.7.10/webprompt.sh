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

cython -2 ../emscripten.pyx -o $BUILD/emscripten.c
# utf_32_be: support Unicode characters e.g. u'é'
PREFIX=$INSTALLDIR OUTDIR=$BUILD ./package-pythonhome.sh \
    encodings/utf_32_be.py

FLAGS='-O3'
while (( $# )); do
    case "$1" in
	debug) FLAGS='-s ASSERTIONS=1 -g -s FETCH_DEBUG=1';;
	async) ASYNC='-s ASYNCIFY=1 -O3';;
    esac
    shift
done
emcc -o $BUILD/index.html \
  webprompt-main.c $BUILD/emscripten.c \
  $FLAGS \
  -I$INSTALLDIR/include/python2.7 -L$INSTALLDIR/lib -lpython2.7 \
  -s EMULATE_FUNCTION_POINTER_CASTS=1 \
  -s USE_ZLIB=1 \
  -s FETCH=1 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s FORCE_FILESYSTEM=1 -s RETAIN_COMPILER_SETTINGS=1 \
  $ASYNC \
  --shell-file webprompt-shell.html -s MINIFY_HTML=0 \
  -s EXPORTED_FUNCTIONS='[_main, _Py_Initialize, _PyRun_SimpleString, _pyruni, _emscripten_debugger]' \
  -s EXTRA_EXPORTED_RUNTIME_METHODS='[ccall, cwrap]'

# cython ../mock/emscripten.pyx -o t/mock.c
# gcc -g -I build/hostpython/include/python2.7 -L build/hostpython/lib/ t/mock.c webprompt-main.c -lpython2.7 -ldl -lm -lutil -lz
# PYTHONHOME=build/hostpython/ ./a.out
