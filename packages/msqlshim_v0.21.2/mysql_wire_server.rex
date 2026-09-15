#!/usr/bin/env rexx
parse arg databaseRoot port host tutorRoot
if databaseRoot = "" then databaseRoot = "example/demo"
if port = "" then port = 3333
if host = "" then host = "127.0.0.1"
if tutorRoot \= "" then ignore = .NoSQLUnicodeSupport~enable(tutorRoot)
server = .MySQLWireServer~new(databaseRoot, host, port)
server~serve
::requires "src/MySQLWireServer.cls"
