/* mu_audit.rex - audit this host, or a recording, against the rexxos-mu contract.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5).  23 Nov 2026; dev3 24 Nov 2026.
 * dev3: when the contract has "check exec" or "watch" lines, the audit also reads
 * the executables in those directories and the files no package owns.
 *
 *   rexx mu_audit.rex CONTRACT                     audit this host
 *   rexx mu_audit.rex CONTRACT record FILE         audit this host and save a recording
 *   rexx mu_audit.rex CONTRACT replay FILE         audit a saved recording
 *
 * Exit code: 0 thin, 1 findings, 2 usage or contract error.
 */
parse arg contractPath mode recordPath
if contractPath == '' then do
  say 'usage: rexx mu_audit.rex CONTRACT [record FILE | replay FILE]'
  exit 2
end
.NewShellLog~setup(.true)
-- dev3: SIGNAL ON SYNTAX, not CATCH, so the audit runs on any ooRexx 5
signal on syntax name failed
contract = .MuContract~new(contractPath)
audit = .MuAudit~new(contract)
if mode == 'replay' then inv = .MuInventory~fromRecording(recordPath)
else inv = .MuInventory~fromHost(contract~execDirs, contract~watchDirs)
if mode == 'record' then .NewShellLog~progress('recording saved to' inv~toRecording(recordPath))
findings = audit~check(inv)
signal off syntax
if findings~items = 0 then do
  say 'THIN: nothing on this MU beyond its contract'
  exit 0
end
do f over findings
  say f~string
end
exit 1

failed:
  c = condition('O')
  detail = c~message
  if c~additional \== .nil, c~additional~items > 0 then detail = c~additional~makeString('L', ' ')
  .error~lineout('[mu_audit] failed:' c~code detail)
  exit 2

::requires '../src/NewShellMuAudit.cls'
