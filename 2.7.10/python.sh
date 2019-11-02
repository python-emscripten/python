#!/bin/bash -ex

# Compile minimal Python for Emscripten and native local testing

# Copyright (C) 2018, 2019  Sylvain Beucler

# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

VERSION=2.7.10  # for end-of-life Python2, support Ren'Py's version only
DESTDIR=${DESTDIR:-$(dirname $(readlink -f $0))/destdir}
SETUPLOCAL=${SETUPLOCAL:-'/dev/null'}

CACHEROOT=$(dirname $(readlink -f $0))
BUILD=$(dirname $(readlink -f $0))/build
export QUILT_PATCHES=$(dirname $(readlink -f $0))/patches

WGET=${WGET:-wget}

unpack () {
    $WGET -c https://www.python.org/ftp/python/$VERSION/Python-$VERSION.tgz -P $CACHEROOT/
    mkdir -p $BUILD
    cd $BUILD/
    rm -rf Python-$VERSION/
    tar xf $CACHEROOT/Python-$VERSION.tgz
    cd Python-$VERSION/
    quilt push -a
}

# TODO: multiple partially supported use cases:
# - python and pgen for emscripten() below
# - mock-ing emscripten environment through static desktop python (but with signal module)
# - building static/dynamic wasm modules (but lacks setuptools and its
#   threads dependency)
# Make several builds?
native () {
    cd $BUILD/Python-$VERSION/
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
        cat $SETUPLOCAL >> Modules/Setup.local

	# used by a Python script in 'make install' - or not
	#echo '_struct _struct.c' >> Modules/Setup.local
	#echo 'unicodedata unicodedata.c' >> Modules/Setup.local

        make -j$(nproc) Parser/pgen python
    
        make -j$(nproc)
        DESTDIR= make install

        # emcc should disregard '-fPIC' during non-SIDE_MODULE builds,
        # otherwise _sysconfigdata.build_time_vars['CCSHARED'] is the culprit:
        # sed -i -e 's/-fPIC//' $BUILD/hostpython/lib/python2.7/_sysconfigdata.py
    )
}

emscripten () {
    cd $BUILD/Python-$VERSION/
    mkdir -p emscripten
    (
        cd emscripten/
        # OPT=-Oz: TODO
        # CONFIG_SITE: deals with cross-compilation https://bugs.python.org/msg136962
        # not needed as emcc has a single arch: BASECFLAGS=-m32 LDFLAGS=-m32
        # --without-threads: pthreads experimental as of 2019-11
        #   cf. https://emscripten.org/docs/porting/pthreads.html

        if [ ! -e config.status ]; then
            CONFIG_SITE=../config.site BASECFLAGS='-s USE_ZLIB=1' \
                emconfigure ../configure \
                --host=asmjs-unknown-emscripten --build=$(../config.guess) \
                --prefix='' \
                --without-threads --without-pymalloc --without-signal-module --disable-ipv6 \
                --disable-shared
        fi
        sed -i -e 's,^#define HAVE_GCC_ASM_FOR_X87.*,/* & */,' pyconfig.h

        # pgen native setup
        # note: need to build 'pgen' once before overwriting it with the native one
        # note: PGEN=../native/Parser/pgen doesn't work, make overwrites it
        emmake make Parser/pgen
        \cp --preserve=mode ../native/Parser/pgen Parser/
        # python native setup
        # note: PATH=... doesn't work, it breaks emcc's /usr/bin/env python
        # note: PYTHON_FOR_BUILD=../native/python neither, it's a more complex call
        #emmake env PATH=../../hostpython/bin:$PATH make -j$(nproc)
        sed -i -e 's,\(PYTHON_FOR_BUILD=.*\) python2.7,\1 $(abs_srcdir)/native/python,' Makefile

        # Modules/Setup.local
        echo '*static*' > Modules/Setup.local
        cat $SETUPLOCAL >> Modules/Setup.local
        # drop -I/-L/-lz, we USE_ZLIB=1 (keep it in SETUPLOCAL for mock)
        sed -i -e 's/^\(zlib zlibmodule.c\).*/\1/' Modules/Setup.local
    
        emmake make -j$(nproc)

        # setup.py install_lib doesn't respect DESTDIR
        echo -e 'sharedinstall:\n\ttrue' >> Makefile
        # decrease .pyo size by dropping docstrings
        sed -i -e '/compileall.py/ s/ -O / -OO /' Makefile
        emmake make install DESTDIR=$DESTDIR

        # Basic trimming
        # Disabled for now, better cherry-pick the files we need
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
        #rm -rf $DESTDIR/lib/python2.7/lib-dynload/
    )
}

case "$1" in
    unpack|native|emscripten)
        "$1"
        ;;
    '')
        unpack
        native
        emscripten
        ;;
    *)
        echo "Usage: $0 unpack|native|emscripten"
        exit 1
        ;;
esac
