/* xtpd_firewall.rex -- the only path from xtpd to the fence.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 24 November 2026.
 * Usage: xtpd_firewall.rex add|remove IPV4 | flush
 * Touches one named set only: XTPD_NFT_FAMILY XTPD_NFT_TABLE XTPD_NFT_SET
 * (default: inet mu_fence xtp_peers).  Runs nft argv-first, never a shell. */
parse arg verb address extra
family = value('XTPD_NFT_FAMILY', , 'ENVIRONMENT'); if family == '' then family = 'inet'
table  = value('XTPD_NFT_TABLE', , 'ENVIRONMENT');  if table == ''  then table = 'mu_fence'
set    = value('XTPD_NFT_SET', , 'ENVIRONMENT');    if set == ''    then set = 'xtp_peers'
nft    = value('XTPD_NFT', , 'ENVIRONMENT');        if nft == ''    then nft = '/usr/sbin/nft'
if extra \== '' then call refuse 'too many arguments'
select
  when verb == 'flush' & address == '' then argv = .array~of(nft, 'flush', 'set', family, table, set)
  when (verb == 'add' | verb == 'remove') then do
    if \ipv4(address) then call refuse 'not an IPv4 address:' address
    if verb == 'remove' then verb = 'delete'
    argv = .array~of(nft, verb, 'element', family, table, set, '{', address, '}')
  end
  otherwise call refuse 'usage: add|remove IPV4 | flush'
end
spec = .ProcessSpec~new(argv)
spec~timeoutMs = 10000
r = .ProcessRunner~new~run(spec)
if \r~succeeded then do
  .error~lineout('xtpd_firewall:' r~stderr~strip r~errorMessage)
  exit 1
end
exit 0
refuse:
  .error~lineout('xtpd_firewall:' arg(1))
  exit 2
ipv4: procedure
  parse arg text
  if text~countStr('.') \= 3 then return 0
  parse var text a '.' b '.' c '.' d
  do part over .array~of(a, b, c, d)
    if part == '' | part~datatype('W') \= 1 | part~length > 3 | part > 255 then return 0
  end
  return 1
::requires 'Process.cls'
