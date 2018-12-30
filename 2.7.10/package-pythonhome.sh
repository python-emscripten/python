#!/bin/bash -e

# Creates a minimal Python file hierarchy at $PACKAGEDIR

# Copyright (C) 2018  Sylvain Beucler

# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

FILE_PACKAGER="python $(dirname $(which emcc))/tools/file_packager.py"

PREFIX=${PREFIX:-$(dirname $(readlink -f $0))/destdir}
PACKAGEDIR=${PACKAGEDIR:-$(dirname $(readlink -f $0))/package}
OUTDIR=${OUTDIR:-.}

# Python home

# Hard-coded modules: for 'print "hello, world."'
# $@: additional, app-specific modules
for i in $(cd $PREFIX/lib/python2.7/ && find site-packages/pygame_sdl2/ -name "*.py") site.py os.py posixpath.py stat.py genericpath.py warnings.py linecache.py types.py UserDict.py _abcoll.py abc.py _weakrefset.py copy_reg.py traceback.py sysconfig.py re.py sre_compile.py sre_parse.py sre_constants.py _sysconfigdata.py encodings/__init__.py codecs.py encodings/aliases.py encodings/utf_8.py __future__.py ast.py copy.py weakref.py platform.py string.py io.py tempfile.py random.py hashlib.py struct.py dummy_thread.py collections.py keyword.py heapq.py argparse.py textwrap.py gettext.py locale.py functools.py importlib/__init__.py glob.py fnmatch.py pickle.py colorsys.py contextlib.py zipfile.py shutil.py json/__init__.py json/decoder.py json/scanner.py encodings/hex_codec.py json/encoder.py difflib.py inspect.py dis.py opcode.py tokenize.py token.py xml/__init__.py xml/etree/__init__.py xml/etree/ElementTree.py xml/etree/ElementPath.py encodings/zlib_codec.py tarfile.py urlparse.py StringIO.py encodings/latin_1.py \
    "$@"; do
    if [ $PREFIX/lib/python2.7/$i -nt $PREFIX/lib/python2.7/${i%.py}.pyo ]; then
	python -OO -m py_compile $PREFIX/lib/python2.7/$i
    fi
    mkdir -p $PACKAGEDIR/lib/python2.7/$(dirname $i)
    cp -au $PREFIX/lib/python2.7/${i%.py}.pyo $PACKAGEDIR/lib/python2.7/${i%.py}.pyo
done

$FILE_PACKAGER \
    $OUTDIR/pythonhome.data --js-output=$OUTDIR/pythonhome-data.js \
    --preload $PACKAGEDIR@/ \
    --use-preload-cache --no-heap-copy
