/* item1_files.rex -- writes the grid item 1 files for one node.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 25 November 2026.
 *
 * Usage (as root, with the kit's rexx):
 *   kit-rexx item1_files.rex ed209k ED209K_IPV4 [DIR]
 *   kit-rexx item1_files.rex cats2  ED209K_IPV4 [DIR]
 * DIR defaults to /etc/xtpd.  Never overwrites a file that exists, except
 * that it refuses to run at all if DIR/xtpd.conf exists.
 *
 * ed209k (LDAP.main): makes the key material on this node -- the two XTP
 *   service keys (xtp.roles, ldap.role) and the TEST role key -- mode 600,
 *   never printed.  Writes the role files: DIR/role (epoch 2, for ed209k) and
 *   DIR/role-for-cats2 (epoch 1, for cats2 to start from).  Listens on UDP
 *   47036 and raw IP 36 at ED209K_IPV4.
 * cats2 (LDAP.spare): expects service.keys, role.keys and role-for-cats2 to have
 *   been copied into DIR already (mode 600, root).  Renames role-for-cats2 to
 *   role.  Does not listen: it only asks ed209k.
 * Neither node gets a firewall_helper: xtpd will not touch any firewall.
 * Prints what it wrote, one line per file, and never a secret. */
parse arg node ip dir extra
if dir == '' then dir = '/etc/xtpd'
if extra \== '' | \.array~of('ed209k', 'cats2')~hasItem(node) | \ipv4(ip) then do
  say 'usage: item1_files.rex ed209k|cats2 ED209K_IPV4 [DIR]'
  exit 2
end
/* the kit is the directory above this tool's bin/; xtpd is the one oorexx_xtpd package in it */
parse source . . me
kit = filespec('location', me)~strip('T', '/')
kit = kit~left(kit~lastPos('/') - 1)
call SysFileTree kit'/pkg/oorexx_xtpd_v*', 'found.', 'DO'
if found.0 \= 1 then do; say 'FAIL cannot find the one xtpd package under' kit'/pkg'; exit 5; end
x = found.1
call SysMkDir dir
if SysFileExists(dir'/xtpd.conf') then do
  say 'FAIL' dir'/xtpd.conf exists: not overwriting anything'
  exit 3
end
if node == 'ed209k' then do
  if \SysFileExists(dir'/service.keys') then do
    s1 = secret(); s2 = secret()
    call put dir'/service.keys', 'xtp.roles' || '09'x || '0000000000017a01' || '09'x || 'authenticate' || '09'x || 'chacha20poly1305' || '09'x || s1 || '0a'x || -
                                 'ldap.role' || '09'x || '0000000000017a02' || '09'x || 'authenticate' || '09'x || 'chacha20poly1305' || '09'x || s2 || '0a'x, '600'
    drop s1 s2
  end
  if \SysFileExists(dir'/role.keys') then do
    rk = secret()
    call put dir'/role.keys', 'test1' rk || '0a'x, '600'
    drop rk
  end
  keys = .XtpdRoleKeys~load(dir'/role.keys')
  if \SysFileExists(dir'/role') then call seal 'ROLE|LDAP|ed209k|cats2|2|1|cats1|test1', keys['test1'], dir'/role'
  if \SysFileExists(dir'/role-for-cats2') then call seal 'ROLE|LDAP|ed209k|cats2|1|1|cats1|test1', keys['test1'], dir'/role-for-cats2'
  drop keys
  call put dir'/services.txt', -
    'xtp.roles management authenticate exec' kit'/bin/kit-rexx' x'/libexec/xtp_roles.rex' dir'/role' || '0a'x || -
    'ldap.role management authenticate exec' kit'/bin/kit-rexx' x'/libexec/ldap_role.rex' dir'/role ed209k 127.0.0.1 1389' || '0a'x, '644'
  call put dir'/peers.txt', 'cats2 4 udp 20.118.224.14:47036' || '0a'x, '644'
  listen = 'listen 4 udp' ip':47036' || '0a'x || 'listen 3 raw36' ip || '0a'x
end
else do
  do f over .array~of('service.keys', 'role.keys', 'role-for-cats2')
    if \SysFileExists(dir'/'f) then do
      say 'FAIL' dir'/'f 'is missing: copy it from ed209k first (mode 600, owner root)'
      exit 4
    end
  end
  if \SysFileExists(dir'/role') then do
    call SysFileMove dir'/role-for-cats2', dir'/role'
    say 'wrote' dir'/role (moved from role-for-cats2)'
  end
  call put dir'/services.txt', '', '644'
  call put dir'/peers.txt', 'ed209k 4 udp' ip':47036' || '0a'x, '644'
  listen = ''
end
call put dir'/xtpd.conf', -
  'socket /run/xtpd/xtpd.sock' || '0a'x || -
  'services' dir'/services.txt' || '0a'x || 'peers' dir'/peers.txt' || '0a'x || -
  'keys' dir'/service.keys' || '0a'x || 'routes /run/xtpd/routes.tsv' || '0a'x || listen || -
  'node' node || '0a'x || 'role_file' dir'/role' || '0a'x || 'role_keys' dir'/role.keys' || '0a'x || -
  'role_timeout_ms 3000' || '0a'x || 'log /var/log/xtpd.log' || '0a'x, '644'
say 'PASS item1 files for' node 'in' dir
exit 0

secret: procedure
  s = .stream~new('/dev/urandom'); s~open('read'); b = s~charin(, 32)   /* a transient stream: no position */; s~close
  return b~c2x~lower
seal: procedure
  use arg canonical, key, out
  call put out, canonical || '0a'x || 'test1' || '0a'x || .HMACSHA512~digest(key, 'XTP-ROLE-TEST/1:'canonical), '600'
  return
put: procedure
  use arg path, bytes, mode
  if SysFileExists(path) then do; say 'kept' path '(exists)'; return; end
  /* create it empty with its final mode first, so a secret is never readable by others */
  address system 'install -m' mode '/dev/null' path
  s = .stream~new(path); s~open('write replace'); s~charout(bytes); s~close
  address system 'chmod' mode path
  say 'wrote' path '(mode' mode')'
  return
ipv4: procedure
  use arg t
  if t~countStr('.') \= 3 then return .false
  parse var t a '.' b '.' c '.' d
  do p over .array~of(a, b, c, d)
    if p == '' | p~datatype('W') \= 1 | p < 0 | p > 255 then return .false
  end
  return .true
::requires 'Xtpd.cls'
::requires 'crypto.cls'
