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

#include <emscripten.h>
#include <Python.h>
PyMODINIT_FUNC initemscripten(void);

int main(int argc, char**argv) {
  Py_OptimizeFlag = 2;  // look for .pyo rather than .pyc
  Py_InitializeEx(0);  // get rid of 'Calling stub instead of sigaction()'
  static struct _inittab builtins[] = { {"emscripten", initemscripten}, };
  PyImport_ExtendInittab(builtins);
  return 0;
}