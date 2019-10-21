# Python wrapper for emscripten_* C functions

# Copyright (C) 2018, 2019  Sylvain Beucler

# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# http://docs.cython.org/en/latest/src/tutorial/strings.html#auto-encoding-and-decoding
# Most of our strings are converted from/to JS through emscripten stringToUTF8/UTF8ToString
# cython: c_string_type=unicode, c_string_encoding=utf8
# Note: Py->C auto-UTF-8 (instead of .encode('UTF-8')) not supported for Py2

cdef extern from "emscripten.h":
    ctypedef void (*em_callback_func)()
    ctypedef void (*em_arg_callback_func)(void*)
    ctypedef void (*em_async_wget_onload_func)(void*, void*, int)

    void emscripten_set_main_loop(em_callback_func func, int fps, int simulate_infinite_loop)
    void emscripten_set_main_loop_arg(em_arg_callback_func func, void *arg, int fps, int simulate_infinite_loop)
    void emscripten_exit_with_live_runtime()
    void emscripten_sleep(unsigned int ms)
    void emscripten_sleep_with_yield(unsigned int ms)
    void emscripten_run_script(const char *script)
    int emscripten_run_script_int(const char *script)
    char *emscripten_run_script_string(const char *script)
    void emscripten_async_call(em_arg_callback_func func, void *arg, int millis)
    #void emscripten_async_wget(const char* url, const char* file, em_str_callback_func onload, em_str_callback_func onerror)
    void emscripten_async_wget_data(const char* url, void *arg, em_async_wget_onload_func onload, em_arg_callback_func onerror)

cdef extern from "emscripten/html5.h":
    ctypedef int EM_BOOL
    ctypedef int EMSCRIPTEN_RESULT
    enum: EM_TRUE
    enum: EM_FALSE

from libc.stdint cimport uint32_t, uint64_t

cdef extern from "emscripten/fetch.h":
    ctypedef struct emscripten_fetch_attr_t:
        char requestMethod[32]
        void *userData
        void (*onsuccess)(emscripten_fetch_t *fetch)
        void (*onerror)(emscripten_fetch_t *fetch)
        void (*onprogress)(emscripten_fetch_t *fetch)
        void (*onreadystatechange)(emscripten_fetch_t *fetch)
        uint32_t attributes
        unsigned long timeoutMSecs
        EM_BOOL withCredentials
        const char *destinationPath
        const char *userName
        const char *password
        const char * const *requestHeaders
        const char *overriddenMimeType
        const char *requestData
        size_t requestDataSize

    ctypedef struct emscripten_fetch_t:
        unsigned int id
        void *userData
        const char *url
        const char *data
        uint64_t numBytes
        uint64_t dataOffset
        uint64_t totalBytes
        unsigned short readyState
        unsigned short status
        char statusText[64]
        uint32_t __proxyState
        emscripten_fetch_attr_t __attributes

    enum:
        EMSCRIPTEN_FETCH_LOAD_TO_MEMORY
        EMSCRIPTEN_FETCH_STREAM_DATA
        EMSCRIPTEN_FETCH_PERSIST_FILE
        EMSCRIPTEN_FETCH_APPEND
        EMSCRIPTEN_FETCH_REPLACE
        EMSCRIPTEN_FETCH_NO_DOWNLOAD
        EMSCRIPTEN_FETCH_SYNCHRONOUS
        EMSCRIPTEN_FETCH_WAITABLE

    void emscripten_fetch_attr_init(emscripten_fetch_attr_t *fetch_attr)
    emscripten_fetch_t *emscripten_fetch(emscripten_fetch_attr_t *fetch_attr, const char *url)
    #EMSCRIPTEN_RESULT emscripten_fetch_wait(emscripten_fetch_t *fetch, double timeoutMSecs)
    EMSCRIPTEN_RESULT emscripten_fetch_close(emscripten_fetch_t *fetch)
    #size_t emscripten_fetch_get_response_headers_length(emscripten_fetch_t *fetch)
    #size_t emscripten_fetch_get_response_headers(emscripten_fetch_t *fetch, char *dst, size_t dstSizeBytes)
    #char **emscripten_fetch_unpack_response_headers(const char *headersString)
    #void emscripten_fetch_free_unpacked_response_headers(char **unpackedHeaders)

FETCH_LOAD_TO_MEMORY = EMSCRIPTEN_FETCH_LOAD_TO_MEMORY
FETCH_STREAM_DATA = EMSCRIPTEN_FETCH_STREAM_DATA
FETCH_PERSIST_FILE = EMSCRIPTEN_FETCH_PERSIST_FILE
FETCH_APPEND = EMSCRIPTEN_FETCH_APPEND
FETCH_REPLACE = EMSCRIPTEN_FETCH_REPLACE
FETCH_NO_DOWNLOAD = EMSCRIPTEN_FETCH_NO_DOWNLOAD
FETCH_SYNCHRONOUS = EMSCRIPTEN_FETCH_SYNCHRONOUS
FETCH_WAITABLE = EMSCRIPTEN_FETCH_WAITABLE


# https://cython.readthedocs.io/en/latest/src/tutorial/memory_allocation.html
from libc.stdlib cimport malloc, free
from cpython.mem cimport PyMem_Malloc, PyMem_Free
# https://github.com/cython/cython/wiki/FAQ#what-is-the-difference-between-pyobject-and-object
from cpython.ref cimport PyObject, Py_XINCREF, Py_XDECREF

from libc.string cimport strncpy

from cpython.oldbuffer cimport PyBuffer_FromMemory
#from cython cimport view

#cdef extern from "stdio.h":
#    int puts(const char *s);


cdef void callpyfunc(void *py_function):
    # not necessary as we're using a no-threading Python
    #PyEval_InitThreads()
    # Call Python function from C using (<object>)()
    (<object>py_function)()

cdef struct callpyfunc_s:
    PyObject* py_function
    PyObject* arg
cdef void callpyfunc_arg(void* p):
    s = <callpyfunc_s*>p
    py_function = <object>(s.py_function)
    arg = <object>(s.arg)
    (py_function)(arg)
    Py_XDECREF(s.py_function)
    Py_XDECREF(s.arg)
    free(s)


def set_main_loop(py_function, fps, simulate_infinite_loop):
    #print "def: set_main_loop", py_function, fps, simulate_infinite_loop
    emscripten_set_main_loop_arg(callpyfunc, <PyObject*>py_function, fps, simulate_infinite_loop)

def async_call(func, arg, millis):
    #print "def: async_call", func, arg, millis
    cdef callpyfunc_s* s = <callpyfunc_s*> malloc(sizeof(callpyfunc_s))
    s.py_function = <PyObject*>func
    s.arg = <PyObject*>arg
    Py_XINCREF(s.py_function)
    Py_XINCREF(s.arg)
    emscripten_async_call(callpyfunc_arg, <void*>s, millis)

def exit_with_live_runtime():
    emscripten_exit_with_live_runtime();

def sleep(ms):
    emscripten_sleep(ms)

def sleep_with_yield(ms):
    emscripten_sleep_with_yield(ms)

def run_script(script):
    emscripten_run_script(script.encode('UTF-8'));

def run_script_int(script):
    return emscripten_run_script_int(script.encode('UTF-8'));

def run_script_string(script):
    return emscripten_run_script_string(script.encode('UTF-8'));

# async_wget
# Requires a C function without parameter, while we need to set
# callpyfunc_arg as callback (so we can call a Python function)
# Perhaps doable if we maintain a list of Python callbacks indexed by 'file' (and ignore potential conflict)
# Or dynamically generate C callbacks in WebAssembly but I doubt that's simple.
# Or implement it with async_wget_data + write output file manually (implies an additional copy)
#def async_wget(url, file, onload, onerror):
#    pass

cdef struct callpyfunc_async_wget_s:
    PyObject* onload
    PyObject* onerror
    PyObject* arg
cdef void callpyfunc_async_wget_onload(void* p, void* buf, int size):
    s = <callpyfunc_async_wget_s*>p
    # https://cython.readthedocs.io/en/latest/src/tutorial/strings.html#passing-byte-strings
    py_buf = (<char*>buf)[:size]  # TODO: avoid copy?
    (<object>(s.onload))(<object>(s.arg), py_buf)
    Py_XDECREF(s.onload)
    Py_XDECREF(s.onerror)
    Py_XDECREF(s.arg)
    free(s)
    # 'buf' freed by emscripten
cdef void callpyfunc_async_wget_onerror(void* p):
    s = <callpyfunc_async_wget_s*>p
    if <object>s.onerror is not None:
        (<object>(s.onerror))(<object>(s.arg))
    Py_XDECREF(s.onload)
    Py_XDECREF(s.onerror)
    Py_XDECREF(s.arg)
    free(s)

def async_wget_data(url, arg, onload, onerror=None):
    cdef callpyfunc_async_wget_s* s = <callpyfunc_async_wget_s*> malloc(sizeof(callpyfunc_async_wget_s))
    s.onload = <PyObject*>onload
    s.onerror = <PyObject*>onerror
    s.arg = <PyObject*>arg
    Py_XINCREF(s.onload)
    Py_XINCREF(s.onerror)
    Py_XINCREF(s.arg)
    emscripten_async_wget_data(url.encode('UTF-8'), <void*>s, callpyfunc_async_wget_onload, callpyfunc_async_wget_onerror)
# emscripten.async_wget_data('/', {'a':1}, lambda arg,buf: sys.stdout.write(repr(arg)+"\n"+repr(buf)+"\n"), lambda arg: sys.stdout.write(repr(arg)+"\nd/l error\n"))
# emscripten.async_wget_data('https://bank.confidential/', None, None, lambda arg: sys.stdout.write("d/l error\n"))
# emscripten.async_wget_data('https://bank.confidential/', None, None)


cdef struct callpyfunc_fetch_s:
    PyObject* py_fetch_attr

cdef void callpyfunc_fetch_callback(emscripten_fetch_t *fetch, char* cb_name):
    s = <callpyfunc_fetch_s*>(fetch.userData)
    py_fetch_attr = <dict>(s.py_fetch_attr)

    # TODO: create a py_emscripten_fetch_t Python object?
    # http://docs.cython.org/en/latest/src/userguide/extension_types.html
    # TODO: possibly with a buffer interface + call fetch_close() on deref
    #cdef char[:] data
    #cdef view.array data
    if fetch.data != NULL:
        #data = fetch.data[:fetch.numBytes]  # copy
        data = PyBuffer_FromMemory(<void*>fetch.data, fetch.numBytes)
        #data = <char[:fetch.numBytes]> fetch.data
    f = {
        'id': fetch.id,
        'userData': py_fetch_attr.get('userData', None),
        'url': fetch.url,
        'data': (fetch.data != NULL) and data or None,
        'dataOffset': fetch.dataOffset,
        'totalBytes': fetch.totalBytes,  # Content-Length
        'readyState': fetch.readyState,
        'status': fetch.status,
        'statusText': fetch.statusText,
    }
    if py_fetch_attr.get(cb_name, None) is not None:
        (<object>(py_fetch_attr[cb_name]))(f)

# one of {onsuccess,onerror} is guaranteed to run, free memory there
cdef void callpyfunc_fetch_onsuccess(emscripten_fetch_t *fetch):
    callpyfunc_fetch_callback(fetch, "onsuccess")
    fetch_pyfree(fetch)
cdef void callpyfunc_fetch_onerror(emscripten_fetch_t *fetch):
    callpyfunc_fetch_callback(fetch, "onerror")
    fetch_pyfree(fetch)
cdef void callpyfunc_fetch_onprogress(emscripten_fetch_t *fetch):
    callpyfunc_fetch_callback(fetch, "onprogress")
cdef void callpyfunc_fetch_onreadystatechange(emscripten_fetch_t *fetch):
    callpyfunc_fetch_callback(fetch, "onreadystatechange")

# Currently unsafe:
# https://github.com/emscripten-core/emscripten/issues/8234
#def fetch_close(fetch):
    # TODO: wrap emscripten_fetch_t
    #fetch_pyfree(*fetch)
    #emscripten_fetch_close(fetch)
    #PyMem_Free(fetch)
    pass

cdef fetch_pyfree(emscripten_fetch_t *fetch):
    s = <callpyfunc_fetch_s*>(fetch.userData)
    Py_XDECREF(s.py_fetch_attr)
    PyMem_Free(fetch.userData)
    fetch.userData = NULL
    emscripten_fetch_close(fetch)

def fetch(py_fetch_attr, url):
    # TODO: dict -> keyword args?
    VALID_ATTRS = (
        'requestMethod', 'userData',
        'onsuccess', 'onerror', 'onprogress', 'onreadystatechange',
        'attributes', 'timeoutMSecs', 'withCredentials',
        'destinationPath', 'userName', 'password',
        'requestHeaders', 'overriddenMimeType', 'requestData')
    for k in py_fetch_attr.keys():
        if k not in VALID_ATTRS:
            print('emscripten: fetch: invalid attribute ' + k)

    # Keep track of temporary Python strings we pass emscripten_fetch() for copy
    py_str_refs = []

    cdef emscripten_fetch_attr_t attr
    emscripten_fetch_attr_init(&attr)

    if py_fetch_attr.has_key('requestMethod'):
        strncpy(attr.requestMethod,
            py_fetch_attr['requestMethod'].encode('UTF-8'),
            sizeof(attr.requestMethod) - 1)

    cdef callpyfunc_fetch_s* s = <callpyfunc_fetch_s*> PyMem_Malloc(sizeof(callpyfunc_fetch_s))
    s.py_fetch_attr = <PyObject*>py_fetch_attr
    Py_XINCREF(s.py_fetch_attr)
    attr.userData = s

    attr.onsuccess = callpyfunc_fetch_onsuccess
    attr.onerror = callpyfunc_fetch_onerror
    if py_fetch_attr.has_key('onprogress'):
        attr.onprogress = callpyfunc_fetch_onprogress
    if py_fetch_attr.has_key('onreadystatechange'):
        attr.onreadystatechange = callpyfunc_fetch_onreadystatechange

    if py_fetch_attr.has_key('attributes'):
        attr.attributes = py_fetch_attr['attributes']
    if py_fetch_attr.has_key('timeoutMSecs'):
        attr.timeoutMSecs = py_fetch_attr['timeoutMSecs']
    if py_fetch_attr.has_key('withCredentials'):
        attr.withCredentials = py_fetch_attr['withCredentials']
    if py_fetch_attr.has_key('destinationPath'):
        py_str_refs.append(py_fetch_attr['destinationPath'].encode('UTF-8'))
        attr.destinationPath = py_str_refs[-1]
    if py_fetch_attr.has_key('userName'):
        py_str_refs.append(py_fetch_attr['userName'].encode('UTF-8'))
        attr.userName = py_str_refs[-1]
    if py_fetch_attr.has_key('password'):
        py_str_refs.append(py_fetch_attr['password'].encode('UTF-8'))
        attr.password = py_str_refs[-1]

    cdef char** headers
    if py_fetch_attr.has_key('requestHeaders'):
        size = (2 * len(py_fetch_attr['requestHeaders']) + 1) * sizeof(char*)
        headers = <char**>PyMem_Malloc(size)
        i = 0
        for name,value in py_fetch_attr['requestHeaders'].items():
            py_str_refs.append(name.encode('UTF-8'))
            headers[i] = py_str_refs[-1]
            i += 1
            py_str_refs.append(value.encode('UTF-8'))
            headers[i] = py_str_refs[-1]
            i += 1
        headers[i] = NULL
        attr.requestHeaders = <const char* const *>headers

    if py_fetch_attr.has_key('overriddenMimeType'):
        py_str_refs.append(py_fetch_attr['overriddenMimeType'].encode('UTF-8'))
        attr.overriddenMimeType = py_str_refs[-1]

    if py_fetch_attr.has_key('requestData'):
        size = len(py_fetch_attr['requestData'])
        attr.requestDataSize = size
        # direct pointer, no UTF-8 encoding pass:
        attr.requestData = py_fetch_attr['requestData']

    # Fetch
    ret = emscripten_fetch(&attr, url.encode('UTF-8'))

    # Explicitely deref temporary Python strings.  Test for forgotten refs with e.g.:
    # print(attr.overriddenMimeType, attr.destinationPath, attr.userName, attr.password)
    del py_str_refs

    if py_fetch_attr.has_key('requestHeaders'):
        PyMem_Free(<void*>attr.requestHeaders)

    # TODO: wrap ret so we can use fetch_*_response_headers()
    #return ret

# import emscripten,sys; f=lambda x:sys.stdout.write(repr(x)+"\n");
# #Module.cwrap('PyRun_SimpleString', 'number', ['string'])("def g(x):\n    global a; a=x")
# emscripten.fetch({'onsuccess':lambda x:sys.stdout.write(repr(x)+"\n")}, '/')
# emscripten.fetch({'attributes':emscripten.FETCH_LOAD_TO_MEMORY,'onsuccess':f}, '/hello'); del f  # output
# fetch_attr={'onsuccess':f; emscripten.fetch(fetch_attr, '/hello'); del fetch_attr['onsuccess']  # no output
# TODO: ^^^ store onxxxxx in callpyfunc_fetch_s
# emscripten.fetch({'onerror':lambda x:sys.stdout.write(repr(x)+"\n")}, '/non-existent')
# emscripten.fetch({'attributes':emscripten.FETCH_LOAD_TO_MEMORY|emscripten.FETCH_PERSIST_FILE, 'onsuccess':f}, '/hello')
# emscripten.fetch({'requestMethod':'EM_IDB_DELETE', 'onsuccess':f}, '/hello')
# emscripten.fetch({'attributes':emscripten.FETCH_LOAD_TO_MEMORY,'requestMethod':'POST','requestData':'AA\xffBB\x00CC','onsuccess':f,'onerror':f}, '/hello')
# emscripten.fetch({'attributes':emscripten.FETCH_LOAD_TO_MEMORY,'requestMethod':'12345678901234567890123456789012','onerror':f}, '/hello')
# emscripten.fetch({'attributes':emscripten.FETCH_LOAD_TO_MEMORY|emscripten.FETCH_PERSIST_FILE,'onsuccess':f,'destinationPath':'destinationPath','overriddenMimeType':'text/html','userName':'userName','password':'password','requestHeaders':{'Content-Type':'text/plain','Cache-Control':'no-store'}}, '/hello'); emscripten.fetch({'requestMethod':'EM_IDB_DELETE', 'onsuccess':f}, 'destinationPath')

def syncfs():
    emscripten_run_script(r"""
        FS.syncfs(false, function(err) {
            if (err) {
                console.trace(); console.log(err, err.message);
                Module.print("Warning: write error: " + err.message + "\n");
            }
        })
    """);
