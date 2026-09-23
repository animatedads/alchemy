a = .AtomicFile~new
o = .AtomicFileOptions~new
o~durability = 'FULL'
r = a~replace('/tmp/oorexx-atomic-example.txt', 'published' || '0a'x, o)
say 'ok=' r~ok 'published=' r~published 'parentSynced=' r~parentSynced
::requires 'AtomicFile.cls'
