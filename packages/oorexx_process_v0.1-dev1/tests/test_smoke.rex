r = .ProcessRunner~new
s = .ProcessSpec~new(.array~of('/usr/bin/python3', '-c', 'import sys;print(sys.argv[1]);print("ERR", file=sys.stderr)', 'a b'))
s~timeoutMs = 2000
x = r~run(s)
if x~failedToStart then do
  say 'FAIL start' x~errorStage x~errorCode x~errorMessage
  exit 1
end
if x~exitCode <> 0 then do; say 'FAIL exit' x~exitCode; exit 1; end
if x~stdout <> 'a b' || '0a'x then do; say 'FAIL stdout <' x~stdout '>'; exit 1; end
if x~stderr <> 'ERR' || '0a'x then do; say 'FAIL stderr <' x~stderr '>'; exit 1; end
say 'PASS test_smoke'

::requires 'Process.cls'
