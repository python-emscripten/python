Python compilation scripts and patches to run in the browser.

<https://www.beuc.net/python-emscripten/python>

Usage:

`cd 3.8/`  
`./python.sh`  
`./package-pythonhome.sh repr.py base64.py ...`  
`emcc ... -lpython3.8 -s EMULATE_FUNCTION_POINTER_CASTS=1`

See for instance [RenPyWeb](https://github.com/renpy/renpyweb).

Web demo: <https://www.beuc.net/python-emscripten/demo/>

Mirrors:

- <https://gitlab.com/python-emscripten/python>
- <https://github.com/python-emscripten/python>
