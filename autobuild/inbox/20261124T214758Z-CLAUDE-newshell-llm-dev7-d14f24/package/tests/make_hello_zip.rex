/* make_hello_zip.rex DIR good|bad|slow - builds DIR/hello.zip: a C program and a
   Makefile that prints 200 lines of noise before compiling, so a test can
   prove the LLM is sent the error point, not the whole build output.
   Architecture: Tom Dyer. Coding: Claude (Opus 5.5). */
parse arg dir kind .
src = dir'/src_'kind'/hello'
'rm -rf' dir'/src_'kind
.File~new(src)~makeDirs
c = src'/hello.c'
call lineout c, '#include <stdio.h>'
call lineout c, 'int main(void) {'
if kind == 'bad' then call lineout c, '  printf("Hello from newshell\n")'
else call lineout c, '  printf("Hello from newshell\n");'
call lineout c, '  return 0;'
call lineout c, '}'
call stream c, 'c', 'close'
m = src'/Makefile'
if kind == 'slow' then do
  -- a build that takes a lock, compiles, sleeps, links, then drops the lock:
  -- killed mid-run it leaves hello/build.lock and a partial hello.o behind,
  -- and the next build refuses to start while the lock is there
  call lineout m, 'hello: hello.c'
  call lineout m, '09'x'@if [ -f build.lock ]; then echo "error: build.lock exists: a build is running or one died" >&2; exit 1; fi'
  call lineout m, '09'x'touch build.lock'
  call lineout m, '09'x'cc -c hello.c -o hello.o'
  call lineout m, '09'x'sleep 3'
  call lineout m, '09'x'cc -o hello hello.o'
  call lineout m, '09'x'rm -f build.lock'
  call lineout m, 'clean:'
  call lineout m, '09'x'rm -f hello hello.o build.lock'
end
else do
  call lineout m, 'hello: hello.c'
  call lineout m, '09'x'@for i in $$(seq 1 200); do echo "NOISE LINE $$i"; done'
  call lineout m, '09'x'cc -o hello hello.c'
end
call stream m, 'c', 'close'
call SysFileDelete dir'/hello.zip'
'cd' dir'/src_'kind '&& zip -qr ../hello.zip hello'
exit 0
