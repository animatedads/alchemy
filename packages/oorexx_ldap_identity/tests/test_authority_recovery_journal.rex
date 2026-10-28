/* Recovery-journal semantic qualification. */
failed = 0

store = .MemoryIdentityPeerAuthorityJournalStore~new
journal = .IdentityPeerAuthorityJournal~new(store)

s1 = .IdentityPeerAuthoritySnapshot~new('directory-a', 7, 'node-a', '42', 'update-0042', 't1')
call assertTrue journal~persist(s1), 'initial persist'
call assertEqual 7, journal~recover~authorityEpoch, 'recover epoch'
call assertEqual 'node-a', journal~recover~authorityHolder, 'recover holder'

s2 = .IdentityPeerAuthoritySnapshot~new('directory-a', 8, 'node-b', '43', 'update-0043', 't2')
call assertTrue journal~persist(s2), 'promotion persist'
call assertEqual 'node-b', journal~recover~authorityHolder, 'promoted holder'

call expectReject journal, .IdentityPeerAuthoritySnapshot~new('directory-a', 7, 'node-a'), 'epoch regression'
call expectReject journal, .IdentityPeerAuthoritySnapshot~new('directory-a', 8, 'node-c'), 'same epoch holder change'

if failed = 0 then do
  say 'IDENTITY PEER AUTHORITY RECOVERY JOURNAL: OK'
  exit 0
end
say 'IDENTITY PEER AUTHORITY RECOVERY JOURNAL: FAILED' failed
exit 1

assertTrue: procedure expose failed
  use arg actual, label
  if \actual then do
    say 'ASSERT TRUE FAILED:' label
    failed += 1
  end
  return

assertEqual: procedure expose failed
  use arg expected, actual, label
  if expected \== actual then do
    say 'ASSERT EQUAL FAILED:' label 'expected='expected 'actual='actual
    failed += 1
  end
  return

expectReject: procedure expose failed
  use arg journal, snapshot, label
  signal on syntax name rejected
  call journal~persist snapshot
  signal off syntax
  say 'EXPECTED REJECTION DID NOT OCCUR:' label
  failed += 1
  return
rejected:
  say 'EXPECTED REJECTION:' label 'RC='rc 'SIGL='sigl 'CONDITION='condition("C") 'DESCRIPTION='condition("D")
  signal off syntax
  return

::requires '../src/IdentityPeerAuthorityJournal.cls'
