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

#cdef extern from "stdio.h":
#    int puts(const char *s);


# call Python function from C using (<object>)()
cdef void callpyfunc(void *f):
    (<object>f)()

#cdef void callpyfunc_arg(void *s):
#    func = s->func
#    arg = s->arg
#    (<object>func)(arg)


def set_main_loop(func, fps, simulate_infinite_loop):
    #print "def: set_main_loop", func, fps, simulate_infinite_loop
    emscripten_set_main_loop_arg(callpyfunc, <void*>func, fps, simulate_infinite_loop)

def async_call(func, arg, millis):
    #print "def: async_call", func, arg, millis
    # TODO: handle arg, cf. callpyfunc_arg() draft
    emscripten_async_call(callpyfunc, <void*>func, millis)

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
