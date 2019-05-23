#!/bin/bash -ex

# Simple Python prompt for the browser, for smoke testing

# Copyright (C) 2019  Sylvain Beucler

# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

INSTALLDIR=${INSTALLDIR:-$(dirname $(readlink -f $0))/destdir}

mkdir -p t
#cat <<'EOF' > t/main.c
##include <Python.h>
#int main(int argc, char**argv) { Py_InitializeEx(0); }
#EOF
echo 'int main(int argc, char**argv) { }' > t/main.c

# Alternatively: use Emscripten's old binary:
# emscripten/tests/python/python.bc -s ERROR_ON_UNDEFINED_SYMBOLS=0

emcc -o t/webprompt.html \
  t/main.c -I$INSTALLDIR/include/python2.7 -L$INSTALLDIR/lib -lpython2.7 \
  -s WASM=0 \
  -s EMULATE_FUNCTION_POINTER_CASTS=1 \
  -s USE_ZLIB=1 \
  -s TOTAL_MEMORY=256MB \
  --preload-file $INSTALLDIR/lib/python2.7@/lib/python2.7 \
  -s EXPORTED_FUNCTIONS="['_main', '_malloc', '_Py_Initialize', '_PyRun_SimpleString']" \
  -s EXTRA_EXPORTED_RUNTIME_METHODS='["ccall", "cwrap"]'

# TODO: add a textarea in a custom shell.html, meanwhile use the JavaScript Console:
# Module.cwrap('Py_Initialize', 'number', [])();
# Module.cwrap('PyRun_SimpleString', 'number', ['string'])("import sys; print sys.builtin_module_names");
# Module.ccall('PyRun_SimpleString', 'number', ['string'], ["print 'hello'"])
