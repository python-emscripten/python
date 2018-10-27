#!/bin/bash -ex

# Compile minimal Python for Emscripten and native local testing

# Copyright (C) 2018  Sylvain Beucler

# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

CACHEROOT=$(dirname $(readlink -f $0))/../../cache
BUILD=$(dirname $(readlink -f $0))/../../build
INSTALLDIR=$(dirname $(readlink -f $0))/../../install
PATCHESDIR=$(dirname $(readlink -f $0))/patches

unpack () {
    cd $BUILD/
    rm -rf Python-2.7.10/
    tar xf $CACHEROOT/Python-2.7.10.tgz
    cd Python-2.7.10/
    QUILT_PATCHES=$PATCHESDIR quilt push -a
}

native () {
    cd $BUILD/Python-2.7.10/
    mkdir -p native
    (
        cd native/
        # --without-signal-module: not disabled because needed by setup.py
        if [ ! -e config.status ]; then
            ../configure \
                --prefix=$BUILD/hostpython/ \
                --without-threads --without-pymalloc --disable-shared --disable-ipv6
        fi
        echo '*static*' > Modules/Setup.local
        # pygame_sdl2 deps:
        echo 'binascii binascii.c' >> Modules/Setup.local
        echo '_struct _struct.c' >> Modules/Setup.local
        echo '_collections _collectionsmodule.c' >> Modules/Setup.local
        echo 'operator operator.c' >> Modules/Setup.local
        echo 'itertools itertoolsmodule.c' >> Modules/Setup.local
        echo 'time timemodule.c' >> Modules/Setup.local
        echo 'math mathmodule.c _math.c' >> Modules/Setup.local
        # Ren'Py deps:
        echo 'cStringIO cStringIO.c' >> Modules/Setup.local
        echo 'cPickle cPickle.c' >> Modules/Setup.local
        #echo 'signal signalmodule.c' >> Modules/Setup.local  # comment out 'import subprocess'
        echo '_io -I$(srcdir)/Modules/_io _io/bufferedio.c _io/bytesio.c _io/fileio.c _io/iobase.c _io/_iomodule.c _io/stringio.c _io/textio.c' >> Modules/Setup.local
        echo '_random _randommodule.c' >> Modules/Setup.local
        echo '_functools _functoolsmodule.c' >> Modules/Setup.local
        echo 'datetime datetimemodule.c' >> Modules/Setup.local
        echo 'zlib zlibmodule.c -I$(prefix)/include -L$(exec_prefix)/lib -lz' >> Modules/Setup.local
        echo '_md5 md5module.c md5.c' >> Modules/Setup.local
        echo 'array arraymodule.c' >> Modules/Setup.local
	# avoid warnings from hashlib module
        echo '_sha shamodule.c' >> Modules/Setup.local
        echo '_sha256 sha256module.c' >> Modules/Setup.local
        echo '_sha512 sha512module.c' >> Modules/Setup.local

        # enable _struct and unicodedata, used by a Python script in 'make install' - or not
        #echo '_struct _struct.c' >> Modules/Setup.local
        #echo 'unicodedata unicodedata.c' >> Modules/Setup.local

        make -j$(nproc) Parser/pgen python
    
        make -j$(proc)
        make install
    )
}

emscripten () {
    cd $BUILD/Python-2.7.10/
    mkdir -p emscripten
    (
        cd emscripten/
        # OPT=-Oz: TODO
        # CONFIG_SITE: deals with cross-compilation https://bugs.python.org/msg136962
        # not needed as emcc has a single arch: BASECFLAGS=-m32 LDFLAGS=-m32
        # --without-threads: pthreads currently not usable in emscripten (tragically)

        if [ ! -e config.status ]; then
            CONFIG_SITE=../config.site BASECFLAGS='-s USE_ZLIB=1' emconfigure ../configure \
                --host=asmjs-unknown-emscripten --build=$(../config.guess) \
                --prefix=$INSTALLDIR \
                --without-threads --without-pymalloc --without-signal-module --disable-ipv6 \
                --disable-shared
	fi
        sed -i -e 's,^#define HAVE_GCC_ASM_FOR_X87.*,/* & */,' pyconfig.h
        # Modules/Setup.local
        emmake make Parser/pgen  # need to build it once before overwriting it with the native one
        \cp --preserve=mode ../native/Parser/pgen Parser/
        # note: PGEN=../native/Parser/pgen doesn't work, make just overwrites it
        # note: PYTHON_FOR_BUILD=../native/python, PATH=... doesn't work, it breaks emcc's Python
        sed -i -e 's,\(PYTHON_FOR_BUILD=.*\) python2.7,\1 $(abs_srcdir)/native/python,' Makefile
        echo '*static*' > Modules/Setup.local
        # pygame_sdl2 deps:
        echo 'binascii binascii.c' >> Modules/Setup.local
        echo '_struct _struct.c' >> Modules/Setup.local
        echo '_collections _collectionsmodule.c' >> Modules/Setup.local
        echo 'operator operator.c' >> Modules/Setup.local
        echo 'itertools itertoolsmodule.c' >> Modules/Setup.local
        echo 'time timemodule.c' >> Modules/Setup.local
        echo 'math mathmodule.c _math.c' >> Modules/Setup.local
        # Ren'Py deps:
        echo 'cStringIO cStringIO.c' >> Modules/Setup.local
        echo 'cPickle cPickle.c' >> Modules/Setup.local
        #echo 'signal signalmodule.c' >> Modules/Setup.local  # comment out 'import subprocess'
        echo '_io -I$(srcdir)/Modules/_io _io/bufferedio.c _io/bytesio.c _io/fileio.c _io/iobase.c _io/_iomodule.c _io/stringio.c _io/textio.c' >> Modules/Setup.local
        echo '_random _randommodule.c' >> Modules/Setup.local
        echo '_functools _functoolsmodule.c' >> Modules/Setup.local
        echo 'datetime datetimemodule.c' >> Modules/Setup.local
        echo 'zlib zlibmodule.c -I$(prefix)/include -L$(exec_prefix)/lib -lz' >> Modules/Setup.local
        echo '_md5 md5module.c md5.c' >> Modules/Setup.local
        echo 'array arraymodule.c' >> Modules/Setup.local
	# avoid warnings from hashlib module
        echo '_sha shamodule.c' >> Modules/Setup.local
        echo '_sha256 sha256module.c' >> Modules/Setup.local
        echo '_sha512 sha512module.c' >> Modules/Setup.local

        #echo 'strop stropmodule.c' >> Modules/Setup.local  # for platform module -> use sys.platform
        #echo 'zlib zlibmodule.c -I$(prefix)/include -L$(exec_prefix)/lib -lz' >> Modules/Setup.local
    
        emmake make -j$(nproc)
        emmake make install
    
        # Basic trimming
        #emmake make install DESTDIR=$(pwd)/destdir
        #find destdir/ -name "*.py" -print0 | xargs -r0 rm
        #find destdir/ -name "*.pyo" -print0 | xargs -r0 rm  # only keep .pyc, .pyo apparently don't work
        #find destdir/ -name "*.so" -print0 | xargs -r0 rm
        #rm -rf destdir/usr/local/bin/
        #rm -rf destdir/usr/local/share/man/
        #rm -rf destdir/usr/local/include/
        #rm -rf destdir/usr/local/lib/*.a
        #rm -rf destdir/usr/local/lib/pkgconfig/
        #rm -rf destdir/usr/local/lib/python2.7/test/

        # Ditch .so for now, they cause an abort() with dynamic
        # linking unless we recompile all of them as SIDE_MODULE-s
        rm -rf $INSTALLDIR/lib/python2.7/lib-dynload/
    )
}

if [ "$1" = "" ]; then
    echo "Usage: $0 native|emscripten"
    exit 1
fi

"$1"
