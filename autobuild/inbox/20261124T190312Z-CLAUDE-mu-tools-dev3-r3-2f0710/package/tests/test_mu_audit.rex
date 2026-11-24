/* test_mu_audit.rex - mu-tools v0.1-dev3: the executables and unowned-files checks
 * Architecture: Tom Dyer ("if you can't justify them then they ought not be there").
 * Code: Claude (Opus 5.5).  24 Nov 2026.
 *
 *   rexx tests/test_mu_audit.rex WORKDIR       (WORKDIR is created and filled)
 * A fake root with its own /var/lib/dpkg, made from what cats1 showed on 24 Nov:
 * script, perl, gpg and hexdump in /usr/bin, a "typescript" left in /usr/bin by
 * script, and /root/.gnupg made by a bare "gpg". */
parse arg work
if work == '' then do; say 'usage: rexx test_mu_audit.rex WORKDIR'; exit 2; end
here = filespec('location', .context~package~name)
fails = 0
r = work'/root'
call mk r'/usr/bin'; call mk r'/root/.gnupg'; call mk r'/root/.ssh'; call mk r'/etc/alternatives'
call mk r'/var/lib/dpkg/info'; call mk r'/var/lib/dpkg/alternatives'
call mk r'/root/snap/lxd/41283'                            -- cats1, 24 Nov: empty, the trace of a snap
do name over .array~of('bash', 'script', 'perl', 'gpg', 'hexdump', 'orphan', 'sshd')
  call put r'/usr/bin/'name, '#!/bin/sh'
end
address system 'chmod 755' r'/usr/bin/*'
call put r'/usr/bin/typescript', 'Script started'          -- not executable: a file, not a program
call put r'/root/.gnupg/pubring.kbx', 'x'
call put r'/root/.ssh/authorized_keys', 'x'
address system 'ln -s ../../usr/bin/bash' r'/etc/alternatives/editor'
address system 'ln -s ../../etc/alternatives/editor' r'/usr/bin/editor'   -- relative: never the host's own /etc
-- Ubuntu 22.04 packages list /bin/bash although the file is /usr/bin/bash (merged /usr)
call put r'/var/lib/dpkg/info/bash.list', '/.' || '0a'x || '/bin/bash'
call put r'/var/lib/dpkg/info/bsdutils.list', '/usr/bin/script'
call put r'/var/lib/dpkg/info/perl-base.list', '/usr/bin/perl'
call put r'/var/lib/dpkg/info/gpg.list', '/usr/bin/gpg'
call put r'/var/lib/dpkg/info/bsdextrautils.list', '/usr/bin/hexdump'
call put r'/var/lib/dpkg/info/openssh-server:amd64.list', '/usr/sbin/sshd' || '0a'x || '/usr/bin/sshd'
call put r'/var/lib/dpkg/alternatives/editor', 'auto' || '0a'x || '/usr/bin/editor' || '0a'x || '' || '0a'x || '/usr/bin/bash'
call put r'/var/lib/dpkg/status', 'Package: bash' || '0a'x || 'Essential: yes' || '0a'x || '' || '0a'x ||,
  'Package: bsdutils' || '0a'x || 'Essential: yes' || '0a'x || '' || '0a'x ||,
  'Package: perl-base' || '0a'x || 'Essential: yes' || '0a'x || '' || '0a'x ||,
  'Package: gpg' || '0a'x || 'Priority: optional'
contractPath = work'/contract.txt'
call put contractPath,,
  'check exec /usr/bin | test' || '0a'x ||,
  'allow exec-package bash | the shell' || '0a'x ||,
  'allow exec sshd | bring-up' || '0a'x ||,
  'forbid exec recorder script' || '0a'x ||,
  'forbid exec toolkit perl gpg' || '0a'x ||,
  'forbid exec dumper hexdump' || '0a'x ||,
  'watch /usr/bin /root | test' || '0a'x ||,
  'allow file /root/.ssh | bring-up keys'

contract = .MuContract~new(contractPath)
call check contract~execDirs~makeString('L', ' ') == '/usr/bin', 'contract: check exec read'
call check contract~watchDirs~makeString('L', ' ') == '/usr/bin /root', 'contract: watch read'
inv = .MuInventory~new('fixture')~addFiles(contract~execDirs, contract~watchDirs, r)
findings = .MuAudit~new(contract)~check(inv)
lines = .array~new
do f over findings; lines~append(f~string); say '   ' f~string; end
call has lines, 'FORBIDDEN exec     script', 'Essential', 'script is FORBIDDEN and named as Essential (bsdutils)'
call has lines, 'FORBIDDEN exec     perl', 'perl-base, an Essential', 'perl is FORBIDDEN (perl-base, Essential)'
call has lines, 'FORBIDDEN exec     gpg', '(package gpg)', 'gpg is FORBIDDEN, removable'
call has lines, 'FORBIDDEN exec     hexdump', 'byte dumper', 'hexdump is FORBIDDEN as a dumper'
call has lines, 'EXTRA     exec     (no package)', 'orphan', 'an executable no package owns is EXTRA'
call has lines, 'EXTRA     exec     alternatives', 'editor', 'an alternatives link needs a witness too'
call has lines, 'UNOWNED   file     /usr/bin/typescript', 'no package owns it', "script's typescript in /usr/bin is UNOWNED"
call has lines, 'UNOWNED   file     /root/.gnupg/pubring.kbx', '', "gpg's /root/.gnupg is UNOWNED"
call has lines, 'UNOWNED   file     /usr/bin/orphan', '', 'the orphan program is also an UNOWNED file'
call has lines, 'UNOWNED   file     /root/snap/lxd/41283', '', 'an empty directory left by snap is UNOWNED'
call check \hasText(lines, 'bash'), 'bash: allowed by its package, and owned through the /bin spelling'
call check \hasText(lines, 'sshd'), 'sshd: allowed by name'
call check \hasText(lines, 'authorized_keys'), '/root/.ssh: allowed by a file witness'
call check findings~items = 10, 'exactly 10 findings: 4 forbidden, 2 extra, 4 unowned (got' findings~items')'

/* the recording keeps the new kinds, so a replay gives the same findings */
rec = inv~toRecording(work'/fixture.rec')
again = .MuAudit~new(contract)~check(.MuInventory~fromRecording(rec))
call check again~items = findings~items, 'replay of the recording gives the same' findings~items 'findings'

/* a contract with no exec or watch lines reads nothing new (dev2 behaviour) */
plain = .MuContract~new(here'../etc/mu_contract.txt')
call check plain~execDirs~items = 0 & plain~watchDirs~items = 0, 'mu_contract.txt: no exec or watch lines'
cats = .MuContract~new(here'../etc/mu_contract_cats.txt')
call check cats~execDirs~items > 0 & cats~watchDirs~items > 0, 'mu_contract_cats.txt: exec and files checked'
call check cats~witnesses~hasIndex('process dbus-daemon'), 'mu_contract_cats.txt: dbus-daemon keeps a witness'
call check cats~witnesses['process dbus-daemon']~caselessPos('logind') > 0, 'the dbus witness names systemd-logind'

if fails > 0 then do; say 'FAIL mu-tools dev3 tests:' fails 'failed'; exit 1; end
say 'PASS mu-tools dev3 tests'
exit 0

check:
  use arg ok, label
  if ok then say 'PASS' label
  else do; say 'FAIL' label; fails += 1; end
  return
has:
  use arg all, head, part, label
  hit = .false
  do l over all
    if l~startsWith(head), (part == '' | l~pos(part) > 0) then hit = .true
  end
  call check hit, label
  return
hasText: procedure
  use arg all, text
  do l over all
    if l~pos(text) > 0 then return .true
  end
  return .false
mk: procedure
  use arg d
  address system 'mkdir -p' d
  return
put: procedure
  use arg path, text
  s = .stream~new(path); s~open('write replace'); s~lineout(text); s~close
  return

::requires '../src/NewShellMuAudit.cls'
