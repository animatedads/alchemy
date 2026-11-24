r = .ProcessRunner~new
s = .ProcessSpec~new(.array~of('/usr/bin/printf', '%s\\n', 'argv is not shell text'))
x = r~run(s)
say 'termination=' x~termination 'exit=' x~exitCode
say x~stdout
::requires 'Process.cls'
