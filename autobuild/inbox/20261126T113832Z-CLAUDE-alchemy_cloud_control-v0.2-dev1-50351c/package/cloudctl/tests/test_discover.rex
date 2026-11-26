/* test_discover.rex -- tests for "cloudctl discover" (CloudDiscover.cls and the plug-ins' discover).  No cloud.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 7 November 2026.
 * Providers answer through tests/fixtures/discover-fake, which hands other calls on to xtp-fake and dev4's
 * cloud-fake.  The real etc/machines files are copied and adjusted in the test copy only.
 *
 * usage: rexx test_discover.rex CLOUDCTL_DIR SHIM LOGGING_PACKAGE_DIR
 */
parse arg pkg shim logPkg .
if logPkg='' then do
  say 'usage: rexx test_discover.rex CLOUDCTL_DIR SHIM LOGGING_PACKAGE_DIR'
  exit 4
end
address system 'mktemp -d' with output stem d.
root=d.1
base=root'/autobuild'
call build root, base, pkg, shim, logPkg
call value 'CLOUDCTL_PROVIDER_LOG', root'/provider.log', 'ENVIRONMENT'
call value 'ALCHEMY_GCLOUD_ACCOUNT_WRAPPER', base'/cloudctl/tests/fixtures/fake-gcloud-account.sh', 'ENVIRONMENT'
call value 'DISCOVERFAKE_NEXT', root'/xtpbin', 'ENVIRONMENT'
call value 'XTPFAKE_NEXT', root'/dev4bin', 'ENVIRONMENT'
call value 'PATH', root'/fakebin:'value('PATH',,'ENVIRONMENT'), 'ENVIRONMENT'
call lineout root'/vultr.key', 'TESTKEY-123'; call lineout root'/vultr.key'; address system 'chmod 600 "'root'/vultr.key"'; call value 'VULTR_API_KEY_FILE', root'/vultr.key', 'ENVIRONMENT'
t=.directory~new; t~pass=0; t~fail=0
m=base'/cloudctl/etc/machines/'

/* the test copy: blank what discovery should fill; ed209a keeps the real security list (so it DIFFERS) */
call setKeys m'ed209b.machine', 'scope=', 'handle='
call setKeys m'ed209c.machine', 'scope='
call setKeys m'ed209e.machine', 'scope='

/* discover all, read only */
call check t, run(base, root, 'discover')=0, 'discover all rc 0'
call check t, has(root'/out', 'Nothing written'), '... writes nothing without --write'
s=sect(root'/out', '== ed209a', '== ed209b')
call check t, pos('ocid1.instance.fake.A', s)>0, 'OCI: ed209a mapped by address, not by listing order'
call check t, pos('DIFFERS', s)>0, 'OCI: ed209a''s real security list differs from the fake one: reported'
s=sect(root'/out', '== ed209b', '== ed209c')
call check t, pos('ocid1.instance.fake.B', s)>0 & pos('fill', s)>0, 'OCI: ed209b handle and scope to fill'
call check t, pos('lon-free-public-subnet-works', s)>0, 'OCI: subnet named'
s=sect(root'/out', '== ed209c', '== ed209d')
call check t, pos('ED209C-RG:ed209c-nsg', s)>0, 'Azure: NIC NSG as RESOURCE_GROUP:NSG'
s=sect(root'/out', '== ed209d', '== ed209e')
call check t, pos('i-0d1ed209d', s)>0 & pos('sg-0ed209d', s)>0, 'AWS: instance and security group'
s=sect(root'/out', '== ed209e', '== ed209f')
call check t, pos('https-server', s)>0, 'GCP: network tags reported'
call check t, pos('instance-20260906-161857', s)>0 & pos('same', s)>0, 'GCP: handle already right'
s=sect(root'/out', '== ed209f', '== ed209h')
call check t, pos('nothing to discover', s)>0, 'Clouvider: no plug-in, nothing to discover'
s=sect(root'/out', '== ed209h', '== ed209i')
call check t, pos('h-0001', s)>0 & pos('fw-h', s)>0, 'Vultr: ed209h instance and firewall group'
s=sect(root'/out', '== ed209i', '== ed209j')
call check t, pos('ED209I-RG:ed209i-subnet-nsg', s)>0, 'Azure: subnet NSG used when the NIC has none'
s=sect(root'/out', '== ed209k', '')
call check t, pos('none', s)>0 & pos('no firewall group', s)>0, 'Vultr: no firewall group -> scope none'

/* --write fills blanks only, keeps comments, backs up */
call check t, run(base, root, 'discover --write')=0, 'discover --write rc 0'
call check t, fileHas(m'ed209b.machine', 'scope=ocid1.securitylist.oc1.fake'), 'ed209b scope written'
call check t, fileHas(m'ed209b.machine', 'handle=ocid1.instance.fake.B'), 'ed209b handle written'
call check t, \fileHas(m'ed209a.machine', 'scope=ocid1.securitylist.oc1.fake'), 'ed209a: a differing value is never overwritten'
call check t, fileHas(m'ed209b.machine', '# ed209a and ed209b share subnet'), 'comments kept'
call check t, fileHas(m'ed209k.machine', 'scope=none'), 'ed209k scope=none written'
call SysFileTree base'/cloudctl/var/machines-backup/ed209b.machine.*', 'b.', 'FO'
call check t, b.0=1, 'old ed209b file backed up'
call check t, run(base, root, 'discover ed209b')=0 & \has(root'/out', '0A'x'   fill ') & has(root'/out', '0A'x'   same '), 'second run: every row same, nothing left to fill'

/* the grid uses what was written */
call check t, run(base, root, 'xtp ed209k')=0 & has(root'/out', 'SKIPPED: scope=none'), 'xtp skips a machine with scope=none'

/* refusals and ledger */
call setKeys m'ed209d.machine', 'region='
call check t, run(base, root, 'discover ed209d')=2 & has(root'/out', 'needs region='), 'AWS without a region refused'
call setKeys m'ed209d.machine', 'region=eu-north-1', 'address=203.0.113.250'
call check t, run(base, root, 'discover ed209d')=2 & has(root'/out', 'no instance has public address 203.0.113.250'), 'unknown address: not found'
call check t, run(base, root, 'discover ed209zz')=2, 'a machine with no file refused'
call SysFileDelete root'/fakebin/aws'
call check t, run(base, root, 'discover ed209d')=2 & has(root'/out', 'aws is not installed'), 'kit check: a missing CLI is named'
call check t, run(base, root, 'aws machine list --region eu-north-1')=2 & has(root'/err', 'aws is not installed'), 'kit check on ordinary operations too'
call SysFileTree base'/cloudctl/var/ops-*.tsv', 'o.', 'FO'
call check t, countHas(o.1, 'machine discover')>=10, 'every discovery is a ledger row'
call check t, countHas(o.1, 'WRITE')>=1, '... the writing ones marked WRITE'

say 'RESULT pass='t~pass 'fail='t~fail
address system 'rm -rf "'root'"'
if t~fail>0 then exit 1
exit 0

/* ------------------------------------------------------------------------------------------------------------ */
run: procedure
  use strict arg base, root, argText
  address system '"'base'/cloudctl.sh"' argText '</dev/null >"'root'/out" 2>"'root'/err"'
  return rc

text: procedure
  use strict arg file
  if \SysFileExists(file) then return ''
  s=.stream~new(file)
  s~open('read')
  a=.array~new
  do while s~lines>0
    a~append(s~linein)
  end
  s~close
  return a~makeString('L', '0A'x)

has: procedure
  use strict arg file, needle
  return pos(needle, text(file))>0

fileHas: procedure
  use strict arg file, needle
  return pos(needle, text(file))>0

countHas: procedure
  use strict arg file, needle
  n=0
  do l over text(file)~makeArray('0A'x)
    if pos(needle, l)>0 then n=n+1
  end
  return n

sect: procedure
  use strict arg file, from, upto
  s=text(file)
  a=pos(from, s)
  if a=0 then return ''
  if upto='' then return s~substr(a)
  b=pos(upto, s, a+1)
  if b=0 then return s~substr(a)
  return s~substr(a, b-a)

setKeys: procedure
  use strict arg f, ...
  do i=2 to arg()
    parse value arg(i) with k '=' v
    address system "sed -i 's#^"k"=.*$#"k"="v"#' '"f"'"
  end
  return

check: procedure
  use strict arg t, ok, label
  if ok then do
    t~pass=t~pass+1
    say 'PASS' label
  end
  else do
    t~fail=t~fail+1
    say 'FAIL' label
  end
  return

build: procedure
  use strict arg root, base, pkg, shim, logPkg
  address system 'mkdir -p "'base'/cloudctl" "'base'/repo/packages/oorexx_logging_v0.7" "'root'/fakebin" "'root'/xtpbin" "'root'/dev4bin"'
  address system 'cp -r "'pkg'/src" "'pkg'/bin" "'pkg'/etc" "'pkg'/tests" "'pkg'/cloudctl.rex" "'base'/cloudctl/"'
  address system 'if [ ! -d "'base'/cloudctl/etc/machines" ]; then cp -r "'base'/cloudctl/tests/fixtures/registry/." "'base'/cloudctl/etc/"; fi'
  address system 'cp "'shim'" "'base'/cloudctl.sh" && chmod +x "'base'/cloudctl.sh" "'base'/cloudctl/tests/fixtures/"*'
  address system 'cp -r "'logPkg'/src" "'base'/repo/packages/oorexx_logging_v0.7/"'
  f=base'/cloudctl/tests/fixtures'
  address system 'for n in az gcloud aws oci vultr-cli; do ln -s "'f'/discover-fake" "'root'/fakebin/$n"; ln -s "'f'/xtp-fake" "'root'/xtpbin/$n"; ln -s "'f'/cloud-fake" "'root'/dev4bin/$n"; done'
  address system 'ln -s "'base'/cloudctl/tests/fixtures/curl-fake" "'root'/fakebin/curl"'
  return
