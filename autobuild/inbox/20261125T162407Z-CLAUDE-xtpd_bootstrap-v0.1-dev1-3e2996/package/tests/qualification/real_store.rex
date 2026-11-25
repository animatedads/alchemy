/* Claude (Opus 5.5) qualification of ChatGPT's xtpd-bootstrap v0.1-dev1.
   Architecture: Tom Dyer. Exercises XtpRoleFile with the real AtomicFile
   (native provider, FULL, noFollow), which the kit's own suite stubs out. */
parse arg dir
if dir == '' then exit 2
seed = '11'~copies(32)
keys = .directory~new; keys['test1'] = seed
v = .XtpTestRoleVerifier~new(keys)
service = .LogService~new('xtpd-qual')
target = .LogMemoryTarget~new('local', .Log~INTERNAL)
service~addTarget(target)
service~addRule(.LogRule~new('q', 'xtpd', 'QualEmitter', 'EVENT', .Log~INTERNAL, .Log~INTERNAL, .Log~INFO, .nil, .array~of('local')))
logger = service~loggerFor(.QualEmitter~new, 'EVENT', .array~new, .Log~INTERNAL)
a = seal('ROLE|LDAP|ed209k|ed209l|1|1|ed209g|test1', 'test1', seed)
b = seal('ROLE|LDAP|ed209l|ed209k|2|1|ed209g|test1', 'test1', seed)
path = dir'/role'
f = .stream~new(path); f~open('WRITE REPLACE'); f~charout(a); f~close
store = .XtpRoleFile~new(path, .AtomicFile~new, .AtomicFileOptions~new)
boot = .XtpRoleBootstrap~new(store, v, logger)
call check boot~record~main == 'ed209k', 'boot from real file'
call check boot~offer(b) == 'ACCEPTED', 'real AtomicFile FULL publication accepted'
call check .stream~new(path)~charin(1, 9000) == b, 'file on disk holds exact new envelope'
boot2 = .XtpRoleBootstrap~new(.XtpRoleFile~new(path, .AtomicFile~new, .AtomicFileOptions~new), v, logger)
call check boot2~record~main == 'ed209l' & boot2~record~epoch = 2, 'restart reads published record'
/* noFollow: a symlinked role file must not be replaced through the link. */
real = dir'/elsewhere'; g = .stream~new(real); g~open('WRITE REPLACE'); g~charout(b); g~close
link = dir'/linked'
address system 'ln -s' real link
bootL = .XtpRoleBootstrap~new(.XtpRoleFile~new(link, .AtomicFile~new, .AtomicFileOptions~new), v, logger)
c = seal('ROLE|LDAP|ed209k|ed209l|3|1|ed209g|test1', 'test1', seed)
out = bootL~offer(c)
call check out \== 'ACCEPTED', 'noFollow refuses publication through a symlink ('out')'
call check .stream~new(real)~charin(1, 9000) == b, 'symlink target unchanged'
call check bootL~quarantined, 'refused publication quarantines'
opts = .AtomicFileOptions~new; opts~durability = 'NONE'
call check refused(path, opts), 'XtpRoleFile refuses non-FULL options'
say 'QUALIFICATION PASSED'
exit 0
refused: procedure
  use arg p, o
  signal on syntax name no
  x = .XtpRoleFile~new(p, .AtomicFile~new, o)
  return .false
  no:
  return .true
seal: procedure
  use arg r, k, s
  return r || '0a'x || k || '0a'x || .HMACSHA512~digest(s, 'XTP-ROLE-TEST/1:'r)
check: procedure
  use arg ok, label
  if \ok then do; say 'FAIL' label; exit 1; end
  say 'PASS' label
  return
::requires 'AtomicFile.cls'
::requires 'XtpRoleBootstrap.cls'
::class QualEmitter
