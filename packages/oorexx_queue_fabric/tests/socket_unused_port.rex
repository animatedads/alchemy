s = .Socket~new("AF_INET", "SOCK_STREAM", 0)
if s~errno \= 0 then exit 61
ignore = s~setOption("SO_REUSEADDR", 1)
a = .InetAddress~new("127.0.0.1", 0)
if s~bind(a) = -1 then exit 62
actual = s~getSockName
if actual == .nil then exit 63
say actual~port
ignore = s~close
exit 0
::requires "socket.cls"
