# Python wrapper for emscripten_* C functions

# Copyright (C) 2018, 2019  Sylvain Beucler

# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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

# https://cython.readthedocs.io/en/latest/src/tutorial/memory_allocation.html
from libc.stdlib cimport malloc, free
# https://github.com/cython/cython/wiki/FAQ#what-is-the-difference-between-pyobject-and-object
from cpython.ref cimport PyObject, Py_XINCREF, Py_XDECREF


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
    emscripten_run_script(script);

def run_script_int(script):
    return emscripten_run_script_int(script);

def run_script_string(script):
    return emscripten_run_script_string(script);

# async_wget
# Requires a C function without parameter, while we need to set
# callpyfunc_arg as callback (so we can call a Python function)
# Perhaps doable if we maintain a list of Python callbacks indexed by 'file' (and ignore potential conflict)
# Or dynamically generate C callbacks in WebAssembly but I doubt that's simple.
# Or implement it with async_wget_data + write output file manually
#def async_wget(url, file, onload, onerror):
#    pass

cdef struct callpyfunc_async_wget_s:
    PyObject* onload
    PyObject* onerror
    PyObject* arg
cdef void callpyfunc_async_wget_onload(void* p, void* buf, int size):
    s = <callpyfunc_async_wget_s*>p
    # https://cython.readthedocs.io/en/latest/src/tutorial/strings.html#passing-byte-strings
    py_buf = (<char*>buf)[:size]
    (<object>(s.onload))(<object>(s.arg), py_buf)
    Py_XDECREF(s.onload)
    Py_XDECREF(s.onerror)
    Py_XDECREF(s.arg)
    free(s)
cdef void callpyfunc_async_wget_onerror(void* p):
    s = <callpyfunc_async_wget_s*>p
    (<object>(s.onerror))(<object>(s.arg))
    Py_XDECREF(s.onload)
    Py_XDECREF(s.onerror)
    Py_XDECREF(s.arg)
    free(s)

def async_wget_data(url, arg, onload, onerror):
    cdef callpyfunc_async_wget_s* s = <callpyfunc_async_wget_s*> malloc(sizeof(callpyfunc_async_wget_s))
    s.onload = <PyObject*>onload
    s.onerror = <PyObject*>onerror
    s.arg = <PyObject*>arg
    Py_XINCREF(s.onload)
    Py_XINCREF(s.onerror)
    Py_XINCREF(s.arg)
    emscripten_async_wget_data(url, <void*>s, callpyfunc_async_wget_onload, callpyfunc_async_wget_onerror)
# emscripten.async_wget_data('http://localhost:8000/', None, lambda arg,buf: sys.stdout.write(repr(buf)+"\n"), lambda arg: sys.stdout.write("d/l error\n"))

def syncfs():
    emscripten_run_script(r"""
        FS.syncfs(false, function(err) {
            if (err) {
                console.trace(); console.log(err, err.message);
                Module.print("Warning: write error: " + err.message + "\n");
            }
        })
    """);
