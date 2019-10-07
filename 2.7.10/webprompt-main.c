/**
 * Simple Python prompt with static emscripten module available
 * 
 * Copyright (C) 2019  Sylvain Beucler
 *
 * Copying and distribution of this file, with or without
 * modification, are permitted in any medium without royalty provided
 * the copyright notice and this notice are preserved.  This file is
 * offered as-is, without any warranty.
 */

#include <Python.h>
PyMODINIT_FUNC initemscripten(void);

int main(int argc, char**argv) {
  Py_OptimizeFlag = 2; // look for .pyo rather than .pyc
  Py_FrozenFlag   = 1; // drop <exec_prefix> warnings
  Py_VerboseFlag  = 1; // trace modules loading
  Py_InitializeEx(0);  // 0 = get rid of 'Calling stub instead of sigaction()'
  static struct _inittab builtins[] = { {"emscripten", initemscripten}, };
  PyImport_ExtendInittab(builtins);
  return 0;
}

// Run a line *and* display the result
// PyRun_StringFlags only returns a non-None object with Py_eval_input (no 'print' support)
// PyRun_InteractiveOne always reads stdin even with another 'fp', so we redirect stdin
void pyruni() {
  freopen("/tmp/input.py", "rb", stdin);
  PyRun_InteractiveOne(stdin, "<stdin>");
}
