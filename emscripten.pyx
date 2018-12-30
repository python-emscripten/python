# Python wrapper for emscripten_* C functions

# Copyright (C) 2018  Sylvain Beucler

# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

cdef extern from "emscripten.h":
    ctypedef void (*em_callback_func)()
    ctypedef void (*em_arg_callback_func)(void*)
    void emscripten_set_main_loop(em_callback_func func, int fps, int simulate_infinite_loop)
    void emscripten_set_main_loop_arg(em_arg_callback_func func, void *arg, int fps, int simulate_infinite_loop)
    void emscripten_exit_with_live_runtime()
    void emscripten_sleep(unsigned int ms)
    void emscripten_sleep_with_yield(unsigned int ms)
    void emscripten_run_script(const char *script)
    void emscripten_async_call(em_arg_callback_func func, void *arg, int millis)

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

def syncfs():
    emscripten_run_script("FS.syncfs(false, function(err) { if (err) { console.trace(); console.log(err); } })");
