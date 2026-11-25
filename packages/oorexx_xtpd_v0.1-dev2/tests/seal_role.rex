/* seal_role.rex -- writes a role envelope under a TEST key.  Test only: the
 * real Auth signs role records; this stands in for it in the loopback test.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 25 November 2026.
 * Usage: rexx seal_role.rex CANONICAL KEYID SECRETHEX OUTFILE
 * The envelope is the one xtpd_bootstrap reads: canonical, newline, key id,
 * newline, HMAC-SHA512 tag of "XTP-ROLE-TEST/1:" || canonical. */
parse arg canonical keyId secret out
if out == '' then exit 2
bytes = canonical || '0a'x || keyId || '0a'x || .HMACSHA512~digest(secret, 'XTP-ROLE-TEST/1:'canonical)
call SysFileDelete out
s = .stream~new(out)
s~open('write replace')
s~charout(bytes)
s~close
exit 0
::requires 'crypto.cls'
