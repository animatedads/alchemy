/* test_roles_units.rex -- xtpd v0.1-dev2 role pieces without a network.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 25 November 2026.
 * Usage: rexx test_roles_units.rex WORKDIR REXX_BIN ROOT */
parse arg dir rexxBin root
if root == '' then exit 2
fails = 0
/* config: role_file needs node and role_keys; node and timeout are checked */
call conf 'r1', 'role_file /x'
call check refused('r1'), 'role_file without node and role_keys is refused'
call conf 'r2', 'node cats2' || '0a'x || 'role_file /x' || '0a'x || 'role_keys /y'
call check \refused('r2'), 'role_file with node and role_keys is accepted'
call conf 'r3', 'node Bad/Name'
call check refused('r3'), 'a bad node name is refused'
call conf 'r4', 'role_timeout_ms 5'
call check refused('r4'), 'role_timeout_ms below 100 is refused'
/* role keys: format, duplicates, symlink */
call put dir'/k1', 'test1' '11'~copies(32)
k = .XtpdRoleKeys~load(dir'/k1')
call check k['test1'] == '11'~copies(32), 'role key loaded'
call put dir'/k2', 'test1' '11'~copies(32) || '0a'x || 'test1' '22'~copies(32)
call check keysRefused(dir'/k2'), 'a duplicate role key id is refused'
call put dir'/k3', 'test1 xyz'
call check keysRefused(dir'/k3'), 'a non-hex secret is refused'
address system 'ln -sf' dir'/k1' dir'/k4'
call check keysRefused(dir'/k4'), 'a symlinked role key file is refused'
/* xtp_roles hook: serves the exact bytes; refuses a symlink */
env = '0a'x
roleBytes = 'ROLE|LDAP|ed209k|cats2|2|1|cats1|test1' || '0a'x || 'test1' || '0a'x || 'ab'~copies(64)
call put dir'/role', roleBytes
address system rexxBin root'/libexec/xtp_roles.rex' dir'/role >' dir'/served'
call check get(dir'/served') == roleBytes, 'xtp.roles hook serves the exact envelope'
address system 'ln -sf' dir'/role' dir'/rolelink'
address system rexxBin root'/libexec/xtp_roles.rex' dir'/rolelink >' dir'/served2'
call check get(dir'/served2') == '' & rc \= 0, 'xtp.roles hook refuses a symlinked role file'
/* ldap.role hook: answers that need no LDAP server */
call check probe('PROBE MAIN 2 1', 'cats2') == 'DENY NOT_HOLDER', 'probe: this node is not MAIN'
call check probe('PROBE MAIN 2 2', 'ed209k') == 'DENY RECORD_DIFFERS', 'probe: a different version is not confirmed'
call check probe('PROBE BOSS 2 1', 'ed209k') == 'DENY BAD_REQUEST', 'probe: an unknown role is a bad request'
call check probe('HELLO', 'ed209k') == 'DENY BAD_REQUEST', 'probe: a bad verb is a bad request'
call check probe('PROBE MAIN 2 1', 'ed209k') == 'DENY LDAP_DOWN', 'probe: holder at the right record, no LDAP server: LDAP_DOWN'
call check probe('PROBE SPARE 2 1', 'cats2') == 'DENY LDAP_DOWN', 'probe: the spare is checked the same way'
if fails = 0 then say 'PASS xtpd roles units'
exit fails > 0
probe: procedure expose dir rexxBin root
  use arg request, self
  call put dir'/req', request || '0a'x
  /* port 9 on loopback: nothing listens */
  address system rexxBin root'/libexec/ldap_role.rex' dir'/role' self '127.0.0.1 9 <' dir'/req >' dir'/ans'
  parse value get(dir'/ans') with answer '0a'x .
  return answer
conf: procedure expose dir
  use arg name, extra
  call put dir'/'name'.conf', 'socket /s' || '0a'x || 'services /s' || '0a'x || 'peers /p' || '0a'x || 'routes /r' || '0a'x || extra || '0a'x
  return
refused: procedure expose dir
  use arg name
  signal on syntax name no
  c = .XtpdConfig~new(dir'/'name'.conf')
  return .false
  no:
  return .true
keysRefused: procedure
  use arg path
  signal on syntax name no
  k = .XtpdRoleKeys~load(path)
  return .false
  no:
  return .true
put: procedure
  use arg path, bytes
  call SysFileDelete path
  s = .stream~new(path); s~open('write replace'); s~charout(bytes); s~close
  return
get: procedure
  use arg path
  if \SysFileExists(path) then return ''
  s = .stream~new(path); s~open('read'); b = s~charin(1, s~chars); s~close
  if b == .nil then return ''
  return b
check: procedure expose fails
  use arg ok, label
  if ok then say 'PASS' label
  else do; say 'FAIL' label; fails = fails + 1; end
  return
::requires 'Xtpd.cls'
