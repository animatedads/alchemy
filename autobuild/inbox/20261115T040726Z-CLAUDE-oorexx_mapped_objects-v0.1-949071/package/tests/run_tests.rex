/* run_tests.rex -- the Mapped Objects tests in a scratch folder of their own.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
   usage: rexx tests/run_tests.rex     (REXX_PATH as README.md says)
   The log is written with SAY (oorexx_logging v0.7 has no target that writes
   a line as it happens). */
scratch = SysTempFileName("/tmp/mapped-objects-?????")
call SysMkDir scratch
say "run_tests: scratch" scratch
here = .File~new(.context~package~name)~parentFile~absolutePath
address system 'rexx "'here'/t_mapped.rex" "'scratch'"'
code = rc
address system 'rm -rf "'scratch'"'
if code = 0 then say "run_tests: PASS t_mapped"
else say "run_tests: FAIL t_mapped -- exit" code
return code
