Python compilation scripts and patches to run in the browser.

<https://www.beuc.net/python-emscripten/python>

Usage:

`cd 2.7.10/`  
`./python.sh`  
`./package-pythonhome.sh repr.py base64.py ...`  
`emcc ... -lpython2.7 -s EMULATE_FUNCTION_POINTER_CASTS=1`

See for instance [RenPyWeb](https://github.com/renpy/renpyweb).

Web demo: <https://www.beuc.net/python-emscripten/demo/>

Mirrors:

- <https://gitlab.com/python-emscripten/python>
- <https://github.com/python-emscripten/python>
