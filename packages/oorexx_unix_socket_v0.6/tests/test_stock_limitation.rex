signal on syntax name expectedFailure
s = .Socket~new('AF_UNIX', 'SOCK_STREAM', 0)
say 'FAIL stock socket.cls unexpectedly accepted AF_UNIX'
exit 1

expectedFailure:
  say 'PASS stock socket.cls rejects AF_UNIX as expected'
  exit 0

::requires 'socket.cls'
