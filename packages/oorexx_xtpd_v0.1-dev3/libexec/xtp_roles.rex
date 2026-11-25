/* xtp_roles.rex -- the xtp.roles exec hook: serves this node's role file.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 25 November 2026.
 * services.txt:  xtp.roles  management  authenticate  exec /usr/local/bin/rexx /opt/xtpd/libexec/xtp_roles.rex /etc/xtpd/role
 * xtpd runs it with the session on stdin and stdout.  It writes the exact
 * signed envelope and exits; the asker verifies it (it never trusts this hook).
 * Refuses a symbolic link and anything over 8192 bytes: it then writes nothing,
 * and the asker sees an empty answer, which fails verification. */
parse arg path
path = path~strip
if path == '' then exit 2
if \SysFileExists(path) | SysIsFileLink(path) then exit 3
s = .stream~new(path)
if s~open('read') \== 'READY:' then exit 4
bytes = s~charin(1, 8193)
s~close
if bytes~length > 8192 then exit 5
call charout , bytes
exit 0
