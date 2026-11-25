/* ldap_role.rex -- the ldap.role exec hook: the LDAP role probe's answer.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 25 November 2026.
 * services.txt:  ldap.role  management  authenticate  exec /usr/local/bin/rexx /opt/xtpd/libexec/ldap_role.rex /etc/xtpd/role ed209k 127.0.0.1 389
 * Reads one line "PROBE ROLE EPOCH VERSION" (ROLE is MAIN or SPARE) and answers
 * one line:
 *   CONFIRM SELF ROLE EPOCH VERSION   this node holds ROLE in its own role file
 *                                     at exactly that epoch and version, and its
 *                                     local LDAP server answered an LDAP request
 *   DENY REASON                       otherwise
 * The role file is the one xtpd verified and published; this hook only reads it.
 * The LDAP check is a real LDAPv3 anonymous bind to the local server
 * (oorexx_ldap_identity LdapWireClient); any well-formed LDAP answer, success
 * or a result code, proves the server is answering. */
parse arg path self host port extra
if extra \== '' | port == '' then exit 2
line = linein()
if line~length > 200 then line = line~substr(1, 200)   /* at most 200 (left() would pad) */
parse var line verb role epoch version more
if verb \== 'PROBE' | more \== '' | \.array~of('MAIN', 'SPARE')~hasItem(role) then call answer 'DENY BAD_REQUEST'
if \SysFileExists(path) | SysIsFileLink(path) then call answer 'DENY NO_ROLE_FILE'
s = .stream~new(path)
if s~open('read') \== 'READY:' then call answer 'DENY NO_ROLE_FILE'
bytes = s~charin(1, 8193)
s~close
parse var bytes canonical '0a'x .
parse var canonical kind '|' name '|' main '|' spare '|' e '|' v '|' .
if kind \== 'ROLE' | name \== 'LDAP' then call answer 'DENY BAD_ROLE_FILE'
holder = main
if role == 'SPARE' then holder = spare
if holder \== self then call answer 'DENY NOT_HOLDER'
if e \== epoch | v \== version then call answer 'DENY RECORD_DIFFERS'
signal on syntax name ldapFailed
client = .LdapWireClient~new(host, port)
r = client~connect
if \r~ok then call answer 'DENY LDAP_DOWN'
b = client~bind('', '')
if \b~ok & b~code~left(12) \== 'LDAP_RESULT_' then call answer 'DENY LDAP_NO_ANSWER'
call answer 'CONFIRM' self role epoch version
ldapFailed:
  call answer 'DENY LDAP_FAILED'
answer:
  call lineout , arg(1)
  exit 0
::requires 'src/LdapWireClient.cls'
