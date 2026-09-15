use arg module
if .ForeignPython~canImport(module) then exit 0
exit 1
::requires '../rexx/python_foreign.cls'
