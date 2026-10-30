/* Recovery fails closed, and failed management commands leave no revisions. */
numeric digits 30
path='tests/.time_authority_v06_reject.journal'
unused=SysFileDelete(path)
l=.TimeAuthorityLedger~new(path)
seq=l~addCalendar('SCH','Europe/London','term-1',0)
if \rejectBadDate(l) then do; say 'FAIL accepted invalid date'; exit 1; end
if l~revision \= 1 then do; say 'FAIL invalid mutation advanced sequence'; exit 1; end
if \rejectBadAlias(l) then do; say 'FAIL accepted unregistered target'; exit 1; end
if l~revision \= 1 then do; say 'FAIL invalid alias advanced sequence'; exit 1; end
/* A new authority can reconstruct the known-good prefix. */
fresh=.TimeAuthorityLedger~new(path)
if fresh~revision \= 1 then do; say 'FAIL valid prefix'; exit 1; end
/* Multi-writer collisions must not be silently merged. */
seq=l~closeDate('SCH','2026-10-27','Closed',1)
if \rejectExternal(fresh) then do; say 'FAIL stale concurrent writer'; exit 1; end
if fresh~revision \= 2 then do; say 'FAIL reload should see external revision'; exit 1; end
/* Simulate replacing a journal with another valid, same-length sequence. */
unused=SysFileDelete(path)
other=.TimeAuthorityLedger~new(path)
seq=other~addCalendar('DIFF','Europe/London','term-2',0)
seq=other~closeDate('DIFF','2026-10-27','Rewritten history',seq)
if \rejectRewrite(fresh) then do; say 'FAIL allowed rewritten journal'; exit 1; end
/* The damaged record must never be partly accepted. */
unused=SysFileDelete(path)
call lineout path, 'STS6|1|GENESIS|CALENDAR|3|00|01|02|12345|COMMIT'
call lineout path
if \rejectCorrupt(path) then do; say 'FAIL accepted corrupt checksum'; exit 1; end
unused=SysFileDelete(path)
call lineout path, 'STS6|1|GENESIS|CALENDAR|3|534348|4575726F70652F4C6F6E646F6E'
call lineout path
if \rejectCorrupt(path) then do; say 'FAIL accepted partial tail'; exit 1; end
unused=SysFileDelete(path)
say 'PASS: invalid changes, external stale writer, same-sequence rewrite, corrupt and truncated journals rejected'
exit 0
rejectBadDate:
  use strict arg ledger
  signal on syntax name rejection
  q=ledger~closeDate('SCH','2026-02-30','Invalid date',ledger~revision)
  return .false
rejection:
  return .true
rejectBadAlias:
  use strict arg ledger
  signal on syntax name rejection2
  q=ledger~bindPhrase('SCH','dinner','unknown-event',ledger~revision)
  return .false
rejection2:
  return .true
rejectExternal:
  use strict arg ledger
  signal on syntax name rejection3
  q=ledger~closeDate('SCH','2026-10-30','Unsafe race',1)
  return .false
rejection3:
  return .true
rejectRewrite:
  use strict arg ledger
  signal on syntax name rejection4
  q=ledger~closeDate('SCH','2026-10-29','Unsafe rewrite',2)
  return .false
rejection4:
  return .true
rejectCorrupt:
  use strict arg path
  signal on syntax name rejection5
  candidate=.TimeAuthorityLedger~new(path)
  return .false
rejection5:
  return .true
::requires 'TimeAuthorityLedger.cls'
