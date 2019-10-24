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
# Note: causes issues with Typed Memoryviews

from __future__ import print_function

cdef extern from "emscripten.h":
    ctypedef void (*em_callback_func)()
    ctypedef void (*em_arg_callback_func)(void*)
    ctypedef void (*em_async_wget_onload_func)(void*, void*, int)

    void emscripten_set_main_loop(em_callback_func func, int fps, int simulate_infinite_loop)
    void emscripten_set_main_loop_arg(em_arg_callback_func func, void *arg, int fps, int simulate_infinite_loop)
    void emscripten_cancel_main_loop()
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
    size_t emscripten_fetch_get_response_headers_length(emscripten_fetch_t *fetch)
    size_t emscripten_fetch_get_response_headers(emscripten_fetch_t *fetch, char *dst, size_t dstSizeBytes)
    char **emscripten_fetch_unpack_response_headers(const char *headersString)
    void emscripten_fetch_free_unpacked_response_headers(char **unpackedHeaders)

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

from cpython.buffer cimport PyBuffer_FillInfo

from libc.string cimport strncpy

#cdef extern from "stdio.h":
#    int puts(const char *s);


# C callback - no memory management
# Take a single Python object and calls it
cdef void callpyfunc(void *py_function):
    # not necessary as we're using a no-threading Python
    #PyEval_InitThreads()
    # Call Python function from C using (<object>)()
    f = <object>py_function
    f()


# C callbacks - memory management
cdef struct callpyfunc_arg_s:
    PyObject* py_function
    PyObject* py_arg

# Take a Python object and calls it ONCE on passed argument
# C callback for e.g. emscripten_async_call
cdef void callpyfunc_arg_once(void* p):
    s = <callpyfunc_arg_s*>p
    callpyfunc_arg_nofree(s)
    freepyfunc(s)

# Take a Python object and calls it on passed argument
# C callback for e.g. emscripten_set_main_loop_arg
cdef void callpyfunc_arg_nofree(void* p):
    s = <callpyfunc_arg_s*>p
    py_function = <object>(s.py_function)
    if s.py_arg != NULL:
        py_arg = <object>(s.py_arg)
        py_function(py_arg)
    else:
        py_function()

cdef callpyfunc_arg_s* createpyfunc(PyObject* py_function, PyObject* py_arg):
    cdef callpyfunc_arg_s* s = <callpyfunc_arg_s*> PyMem_Malloc(sizeof(callpyfunc_arg_s))
    s.py_function = py_function
    s.py_arg = py_arg
    Py_XINCREF(s.py_function)
    Py_XINCREF(s.py_arg)    
    return s

cdef void freepyfunc(callpyfunc_arg_s *p):
    if p != NULL:
        Py_XDECREF(p.py_function)
        if p.py_arg != NULL:
          Py_XDECREF(p.py_arg)
        PyMem_Free(p)


cdef callpyfunc_arg_s* main_loop

def set_main_loop_arg(py_function, py_arg, fps, simulate_infinite_loop):
    set_main_loop_arg_c(<PyObject*>py_function, <PyObject*>py_arg,
                        fps, simulate_infinite_loop)

def set_main_loop(py_function, fps, simulate_infinite_loop):
    set_main_loop_arg_c(<PyObject*>py_function, NULL,
                        fps, simulate_infinite_loop)

# handle py_arg == NULL != None
cdef set_main_loop_arg_c(PyObject* py_function, PyObject* py_arg,
                         fps, simulate_infinite_loop):
    global main_loop
    if main_loop == NULL:
        main_loop = createpyfunc(py_function, py_arg)
    else:
        pass  # invalid, let emscripten_set_main_loop_arg() abort
    emscripten_set_main_loop_arg(callpyfunc_arg_nofree, <void*>main_loop,
                                 fps, simulate_infinite_loop)

def cancel_main_loop():
    global main_loop
    emscripten_cancel_main_loop()
    freepyfunc(main_loop)
    main_loop = NULL

# import emscripten,sys
# emscripten.set_main_loop(lambda: sys.stdout.write("main_loop\n"), 2, 0)
# emscripten.cancel_main_loop()
# emscripten.set_main_loop(lambda: sys.stdout.write("main_loop\n"), 2, 1)
# emscripten.set_main_loop_arg(lambda a: sys.stdout.write(a), "main_loop_arg\n", 2, 0)

def async_call(py_function, py_arg, millis):
    cdef callpyfunc_arg_s* s = createpyfunc(<PyObject*>py_function, <PyObject*>py_arg)
    emscripten_async_call(callpyfunc_arg_once, <void*>s, millis)

# emscripten.async_call(lambda a: sys.stdout.write(a), "async_call_arg\n", 2000)


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



# Fetch API
# https://emscripten.org/docs/api_reference/fetch.html

# http://docs.cython.org/en/latest/src/userguide/extension_types.html
cdef class Fetch:
    cdef emscripten_fetch_t *fetch
    cdef callbacks

    def __cinit__(self, url, requestMethod=None, userData=None,
            onsuccess=None, onerror=None, onprogress=None, onreadystatechange=None,
            attributes=None, timeoutMSecs=None, withCredentials=None,
            destinationPath=None, userName=None, password=None,
            requestHeaders=None, overriddenMimeType=None, requestData=None):
    
        # Keep track of temporary Python strings we pass emscripten_fetch() for copy
        py_str_refs = []
    
        cdef emscripten_fetch_attr_t attr
        emscripten_fetch_attr_init(&attr)
    
        Py_XINCREF(<PyObject*>self)  # survive until callback
        attr.userData = <PyObject*>self
    
        if requestMethod is not None:
            strncpy(attr.requestMethod,
                requestMethod.encode('UTF-8'),
                sizeof(attr.requestMethod) - 1)
    
        self.userData = userData
    
        self.callbacks = {}
        attr.onsuccess = callpyfunc_fetch_onsuccess
        attr.onerror = callpyfunc_fetch_onerror
        if onsuccess is not None:
            self.callbacks['onsuccess'] = onsuccess
        if onerror is not None:
            self.callbacks['onerror'] = onerror
        if onprogress is not None:
            self.callbacks['onprogress'] = onprogress
            attr.onprogress = callpyfunc_fetch_onprogress
        if onreadystatechange is not None:
            self.callbacks['onreadystatechange'] = onreadystatechange
            attr.onreadystatechange = callpyfunc_fetch_onreadystatechange
    
        if attributes is not None:
            attr.attributes = attributes
        if timeoutMSecs is not None:
            attr.timeoutMSecs = timeoutMSecs
        if withCredentials is not None:
            attr.withCredentials = withCredentials
        if destinationPath is not None:
            py_str_refs.append(destinationPath.encode('UTF-8'))
            attr.destinationPath = py_str_refs[-1]
        if userName is not None:
            py_str_refs.append(userName.encode('UTF-8'))
            attr.userName = py_str_refs[-1]
        if password is not None:
            py_str_refs.append(password.encode('UTF-8'))
            attr.password = py_str_refs[-1]
    
        cdef char** headers
        if requestHeaders is not None:
            size = (2 * len(requestHeaders) + 1) * sizeof(char*)
            headers = <char**>PyMem_Malloc(size)
            i = 0
            for name,value in requestHeaders.items():
                py_str_refs.append(name.encode('UTF-8'))
                headers[i] = py_str_refs[-1]
                i += 1
                py_str_refs.append(value.encode('UTF-8'))
                headers[i] = py_str_refs[-1]
                i += 1
            headers[i] = NULL
            attr.requestHeaders = <const char* const *>headers
    
        if overriddenMimeType is not None:
            py_str_refs.append(overriddenMimeType.encode('UTF-8'))
            attr.overriddenMimeType = py_str_refs[-1]
    
        if requestData is not None:
            size = len(requestData)
            attr.requestDataSize = size
            # direct pointer, no UTF-8 encoding pass:
            attr.requestData = requestData
    
        # Fetch
        cdef emscripten_fetch_t *fetch = emscripten_fetch(&attr, url.encode('UTF-8'))
        self.fetch = fetch
    
        # Explicitely deref temporary Python strings.  Test for forgotten refs with e.g.:
        # print(attr.overriddenMimeType, attr.destinationPath, attr.userName, attr.password)
        del py_str_refs
    
        if requestHeaders is not None:
            PyMem_Free(<void*>attr.requestHeaders)

    def __dealloc__(self):
        emscripten_fetch_close(self.fetch)

    # Currently unsafe:
    # https://github.com/emscripten-core/emscripten/issues/8234
    #def fetch_close(fetch):
    #    pass

    # http://docs.cython.org/en/latest/src/userguide/buffer.html
    # https://docs.python.org/3/c-api/typeobj.html#c.PyBufferProcs.bf_getbuffer
    # https://docs.python.org/3/c-api/buffer.html#c.PyObject_GetBuffer
    # https://docs.python.org/3/c-api/buffer.html#c.PyBuffer_FillInfo
    def __getbuffer__(self, Py_buffer *view, int flags):
        if self.fetch.data != NULL:
            readonly = 1
            PyBuffer_FillInfo(view, self, <void*>self.fetch.data, self.fetch.numBytes, readonly, flags)
        else:
            view.obj = None
            raise BufferError
    def __releasebuffer__(self, Py_buffer *view):
        pass

    def __repr__(self):
        return u'<Fetch: id={}, userData={}, url={}, data={}, dataOffset={}, totalBytes={}, readyState={}, status={}, statusText={}>'.format(repr(self.id), repr(self.userData), repr(self.url), repr(self.data), repr(self.dataOffset), repr(self.totalBytes), repr(self.readyState), repr(self.status), repr(self.statusText))

    # For testing whether a copy occurred:
    #def overwrite(self):
    #    cdef char* overwrite = <char*>(self.fetch.data)
    #    overwrite[0] = b'O'

    def get_response_headers(self):
        cdef char* buf = NULL
        # Note: JS crash if applied on a persisted request from IDB cache
        # https://github.com/emscripten-core/emscripten/issues/7026#issuecomment-545488132
        cdef length = emscripten_fetch_get_response_headers_length(self.fetch)
        if length > 0:
            headersString = <char*>PyMem_Malloc(length)
            emscripten_fetch_get_response_headers(self.fetch, headersString, length+1)
            ret = headersString[:length]  # copy
            PyMem_Free(headersString)
            return ret
        else:
            return None

    def get_unpacked_response_headers(self):
        cdef char* headersString = NULL
        cdef char** unpackedHeaders = NULL
        # Note: JS crash if applied on a persisted request from IDB cache
        cdef length = emscripten_fetch_get_response_headers_length(self.fetch)
        if length > 0:
            headersString = <char*>PyMem_Malloc(length)
            emscripten_fetch_get_response_headers(self.fetch, headersString, length+1)
            unpackedHeaders = emscripten_fetch_unpack_response_headers(headersString)
            PyMem_Free(headersString)
            d = {}
            i = 0
            while unpackedHeaders[i] != NULL:
                k = unpackedHeaders[i]  # c_string_encoding
                i += 1
                v = unpackedHeaders[i]  # c_string_encoding
                i += 1
                d[k] = v
            emscripten_fetch_free_unpacked_response_headers(unpackedHeaders)
            return d
        else:
            return None

    @property
    def id(self):
        return self.fetch.id
    cdef readonly userData
    @property
    def url(self):
        #return self.fetch.url.decode('UTF-8')
        return self.fetch.url  # c_string_encoding
    @property
    def data(self):
        if self.fetch.data != NULL:
            return memoryview(self)
        else:
            return None
    @property
    def dataOffset(self):
        return self.fetch.dataOffset
    @property
    def totalBytes(self):
        return self.fetch.totalBytes  # Content-Length
    @property
    def readyState(self):
        return self.fetch.readyState
    @property
    def status(self):
        return self.fetch.status
    @property
    def statusText(self):
        #return self.fetch.statusText.decode('UTF-8')
        return self.fetch.statusText  # c_string_encoding

cdef void callpyfunc_fetch_callback(emscripten_fetch_t *fetch, char* callback_name):
    cdef Fetch py_fetch = <Fetch>fetch.userData
    # for theoretical concurrency, if we're called during emscripten_fetch()
    py_fetch.fetch = fetch
    # call Python function
    if py_fetch.callbacks.get(callback_name, None):
        py_fetch.callbacks[callback_name](py_fetch)

# one of {onsuccess,onerror} is guaranteed to run, deref Fetch there
cdef void callpyfunc_fetch_onsuccess(emscripten_fetch_t *fetch):
    callpyfunc_fetch_callback(fetch, 'onsuccess')
    Py_XDECREF(<PyObject*>fetch.userData)
cdef void callpyfunc_fetch_onerror(emscripten_fetch_t *fetch):
    callpyfunc_fetch_callback(fetch, 'onerror')
    Py_XDECREF(<PyObject*>fetch.userData)
cdef void callpyfunc_fetch_onprogress(emscripten_fetch_t *fetch):
    callpyfunc_fetch_callback(fetch, 'onprogress')
cdef void callpyfunc_fetch_onreadystatechange(emscripten_fetch_t *fetch):
    callpyfunc_fetch_callback(fetch, 'onreadystatechange')


# import emscripten,sys; f=lambda x:sys.stdout.write(repr(x)+"\n");
# #Module.cwrap('PyRun_SimpleString', 'number', ['string'])("def g(x):\n    global a; a=x")
# emscripten.Fetch('/', onsuccess=f)
# emscripten.Fetch(u'/helloé', onsuccess=f)
# emscripten.Fetch('/hello', attributes=emscripten.FETCH_LOAD_TO_MEMORY, onsuccess=f); del f  # output
# fetch_attr={'onsuccess':f}; emscripten.Fetch('/hello', **fetch_attr); del fetch_attr['onsuccess']  # output
# emscripten.Fetch('/non-existent', onerror=lambda x:sys.stdout.write(repr(x)+"\n"))
# emscripten.Fetch('https://bank.confidential/', onerror=lambda x:sys.stdout.write(repr(x)+"\n"))  # simulated 404
# emscripten.Fetch('/hello', attributes=emscripten.FETCH_LOAD_TO_MEMORY|emscripten.FETCH_PERSIST_FILE, onsuccess=f)
# Note: fe.fetch.id changes (in-place) when first caching
# emscripten.Fetch('/hello', requestMethod='EM_IDB_DELETE', onsuccess=f)
# emscripten.Fetch('/hello', attributes=emscripten.FETCH_LOAD_TO_MEMORY, requestMethod='POST', requestData='AA\xffBB\x00CC', onsuccess=f, onerror=f)
# emscripten.Fetch('/hello', attributes=emscripten.FETCH_LOAD_TO_MEMORY, requestMethod='12345678901234567890123456789012', onerror=f)
# emscripten.Fetch('/hello', attributes=emscripten.FETCH_LOAD_TO_MEMORY, onsuccess=f, userData='userData', overriddenMimeType='text/html', userName='userName', password='password', requestHeaders={'Content-Type':'text/plain','Cache-Control':'no-store'})
# emscripten.Fetch('/hello', attributes=emscripten.FETCH_LOAD_TO_MEMORY|emscripten.FETCH_PERSIST_FILE, onsuccess=f, destinationPath='destinationPath'); emscripten.Fetch('destinationPath', requestMethod='EM_IDB_DELETE', onsuccess=f)
# fe=emscripten.Fetch('/hello', attributes=emscripten.FETCH_LOAD_TO_MEMORY|emscripten.FETCH_PERSIST_FILE, onsuccess=f, destinationPath='destinationPath'); fe2=emscripten.Fetch('destinationPath', requestMethod='EM_IDB_DELETE', onsuccess=f); print("fe=",fe); print("fe2=",fe2)
# Note: fe2 can occur before fe1
# r=emscripten.Fetch('/hello', attributes=emscripten.FETCH_LOAD_TO_MEMORY)
# open('test.txt','wb').write(r); open('test.txt','rb').read()
# open('test.txt','wb').write(r.data); open('test.txt','rb').read()


# Non-API utility

def syncfs():
    emscripten_run_script(r"""
        FS.syncfs(false, function(err) {
            if (err) {
                console.trace(); console.log(err, err.message);
                Module.print("Warning: write error: " + err.message + "\n");
            }
        })
    """);
