/* test_xtp.rex -- tests for "cloudctl xtp" (CloudXtp.cls).  Touches no cloud.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 7 November 2026.
 * Providers answer through tests/fixtures/xtp-fake (grid-shaped firewall state for AWS and the OCI security list),
 * which hands every other call to dev4's cloud-fake.  The real etc/machines files are used, with scopes filled in
 * for the test copy only.
 *
 * 26 Nov 2026 (Claude (Opus 5.5)): add-only, named removals, error reasons, AWS_PAGER.
 *
 * usage: rexx test_xtp.rex CLOUDCTL_DIR SHIM LOGGING_PACKAGE_DIR
 */
parse arg pkg shim logPkg .
if logPkg='' then do
  say 'usage: rexx test_xtp.rex CLOUDCTL_DIR SHIM LOGGING_PACKAGE_DIR'
  exit 4
end
address system 'mktemp -d' with output stem d.
root=d.1
base=root'/autobuild'
call build root, base, pkg, shim, logPkg
log=root'/provider.log'
call value 'CLOUDCTL_PROVIDER_LOG', log, 'ENVIRONMENT'
call value 'ALCHEMY_GCLOUD_ACCOUNT_WRAPPER', base'/cloudctl/tests/fixtures/fake-gcloud-account.sh', 'ENVIRONMENT'
call value 'XTPFAKE_NEXT', root'/dev4bin', 'ENVIRONMENT'
call value 'PATH', root'/fakebin:'value('PATH',,'ENVIRONMENT'), 'ENVIRONMENT'
call lineout root'/vultr.key', 'TESTKEY-123'; call lineout root'/vultr.key'; address system 'chmod 600 "'root'/vultr.key"'; call value 'VULTR_API_KEY_FILE', root'/vultr.key', 'ENVIRONMENT'
t=.directory~new; t~pass=0; t~fail=0
ws='--workstation 198.51.100.7'
call setKeys base, 'ed209f', 'address='            /* the test copy keeps one member without an address */

/* show: the desired matrix, no provider call */
call check t, run(base, root, 'xtp show' ws)=0, 'xtp show rc 0'
call check t, \SysFileExists(log), '... and no provider was called'
call check t, has(root'/out', 'peers-raw+ ed209-xtp-peers'), 'AWS/OCI: workstation raw merged into the peer slot'
call check t, has(root'/out', 'vultr cannot filter IP protocol 36: ed209h peers-raw'), 'Vultr raw slot dropped with a WARN'
call check t, has(root'/out', 'ed209f has no address='), 'a member without an address is named'
call check t, has(root'/out', 'no cloud firewall plug-in for clouvider'), 'ed209f: host firewall only'
e=section(root'/out', '== ed209e', '== ed209f')
call check t, pos('peers-raw', e)=0, 'ed209e (L4): no raw slot'
call check t, pos('193.123.184.140/32', e)>0 & pos('80.240.21.156/32', e)>0, 'ed209e (L4): every peer on UDP'
c=section(root'/out', '== ed209c', '== ed209d')
call check t, pos('ed209-xtp-peers              all', c)>0, 'ed209c (Azure): raw peers as an any-protocol rule'
call check t, pos('34.16.115.198/32', c~substr(pos('ed209-xtp-udp ', c)))>0, 'ed209c: Google nodes on UDP 62801'
call check t, pos('52.146.17.8/32', c~left(pos('ed209-xtp-udp ', c)))=0, 'ed209c: not its own peer'

/* refusals */
call setKeys base, 'ed209a', 'scope=', 'region='
call check t, run(base, root, 'xtp ed209a' ws)=2, 'ed209a without scope/region refused'
call check t, has(root'/out', 'STOP xtpscope') & has(root'/out', 'STOP xtpregion'), '... names scope and region'
call check t, run(base, root, 'xtp ed209z' ws)=2, 'a machine that is not a member refused'
call check t, run(base, root, 'xtp ed209d --workstation 1.2.3')=2, 'a bad workstation CIDR refused'
call check t, run(base, root, 'xtp')=2, 'xtp with no node refused'
call check t, run(base, root, 'xtp ed209d ed209e')=2, 'two nodes refused'

/* fill the scopes in the test copy only */
call setKeys base, 'ed209a', 'scope=ocid1.securitylist.oc1.fake', 'region=uk-london-1'
call setKeys base, 'ed209b', 'scope=ocid1.securitylist.oc1.fake', 'region=uk-london-1'
call setKeys base, 'ed209c', 'scope=rg-c:nsg-c'
call setKeys base, 'ed209d', 'scope=sg-xtp'
call setKeys base, 'ed209h', 'scope=fw-h'
call setKeys base, 'ed209e', 'target-tags=ed209e'

/* AWS: PLAN shows the stale raw36 source removed, kept sources untouched, UDP already right */
call SysFileDelete log
call check t, run(base, root, 'xtp ed209d' ws)=0, 'ed209d PLAN rc 0'
call check t, has(root'/out', "'revoke-security-group-ingress' '--group-id' 'sg-xtp' '--security-group-rule-ids' 'sgr-36old'"), 'stale raw36 source revoked'
call check t, \has(root'/out', 'sgr-36out'), 'egress rule ignored'
call check t, \has(root'/out', "'--cidr' '193.123.184.140/32'"), 'already-allowed raw36 source not added again'
call check t, has(root'/out', "'--protocol' '36' '--cidr' '198.51.100.7/32'"), 'workstation raw36 added'
call check t, has(root'/out', 'NO CHANGE: already as wanted'), 'UDP 62801 slot already as wanted'
call check t, has(root'/out', "'--port' '62000-63000'"), 'workstation UDP range'
call check t, \logHas(log, 'authorize-security-group-ingress'), 'PLAN: nothing reached the provider'

/* OCI security list: one update, kebab rules rewritten camelCase, protocol a JSON string, duplicate dropped */
call check t, run(base, root, 'xtp ed209a' ws)=0, 'ed209a PLAN rc 0'
call check t, has(root'/out', "'security-list' 'update' '--security-list-id' 'ocid1.securitylist.oc1.fake'"), 'one security-list update'
call check t, has(root'/out', '"isStateless":false') & \has(root'/out', '"is-stateless"'), 'kept rules written in camelCase'
call check t, has(root'/out', '"protocol":"36"') & \has(root'/out', '"protocol":36'), 'protocol is a JSON string'
call check t, has(root'/out', '"destinationPortRange":{"max":22,"min":22}'), 'the ssh rule is kept'
raw=section(root'/out', '--  peers-raw', '--  peers-udp')
call check t, pos('"source":"203.0.113.99', raw)=0, 'stale raw36 source dropped'
call check t, pos('REMOVE 203.0.113.99/32', raw)>0, '... and the plan names it (26 Nov 2026: no hidden removal)'
call check t, raw~countStr('"source":"52.146.17.8\/32"')=1, 'duplicate peer rule written once'
call check t, pos('null', raw)=0, 'null fields from get are not written back'
call check t, has(root'/out', '"udpOptions":{"destinationPortRange":{"max":62801,"min":62801}}'), 'UDP commissioned port rule'
call check t, has(root'/out', 'ed209a shares its firewall scope with ed209b'), 'shared security list found'
call check t, pos('"source":"193.123.184.140\/32"', raw)>0, 'shared list keeps ed209a''s own address (from ed209b''s set)'
call check t, pos('"source":"193.123.190.35\/32"', raw)>0, '... and ed209b''s'
call check t, run(base, root, 'xtp ed209b' ws)=0, 'ed209b PLAN rc 0'
rawB=section(root'/out', '--  peers-raw', '--  peers-udp')
call check t, rawB~countStr('"source":')=raw~countStr('"source":'), 'ed209a and ed209b plan the same list (no flapping)'
call check t, run(base, root, 'xtp ed209d --apply' ws)=0, 'APPLY lists no steps on stdout'
call check t, \has(root'/out', '    CHANGE '), '... (stderr announces each one)'
call check t, has(root'/err', 'cloudctl: > CHANGE'), '... announced on stderr'

/* Azure, GCP, Vultr */
call check t, run(base, root, 'xtp ed209c' ws)=0, 'ed209c PLAN rc 0'
call check t, has(root'/out', "'update' '--resource-group' 'rg-c' '--nsg-name' 'nsg-c' '--name' 'ed209-xtp-peers' '--priority' '250'"), 'azure peers rule, priority 250'
call check t, has(root'/out', "'--name' 'ed209-xtp-workstation-udp' '--priority' '247'"), 'azure workstation UDP rule, priority 247'
call check t, run(base, root, 'xtp ed209e' ws)=0, 'ed209e PLAN rc 0'
call check t, has(root'/out', "'udp:62801'") & has(root'/out', "'--target-tags' 'ed209e'"), 'gcp UDP rule with target tags'
call check t, \has(root'/out', 'xtptags'), '... and no target-tags warning'
call check t, run(base, root, 'xtp ed209h' ws)=0, 'ed209h PLAN rc 0'
call check t, \has(root'/out', '"protocol":"36"'), 'vultr: no protocol 36 rule'
call check t, has(root'/out', '"port":"62000:63000"'), 'vultr: port range written N:M'
call check t, has(root'/out', "'DELETE' '/firewalls/fw-h/rules/vfr-old'"), 'vultr: stale UDP source removed by rule id'
call check t, \has(root'/out', '"subnet":"34.16.115.198"'), 'vultr: an existing wanted source is not added again'
call check t, has(root'/out', '"subnet":"34.44.126.133"'), 'vultr: the missing peer is added'

/* APPLY */
call SysFileDelete log
call check t, run(base, root, 'xtp ed209d --apply --job-id xtp-test-1' ws)=0, 'ed209d APPLY rc 0'
call check t, logHas(log, 'aws ec2 revoke-security-group-ingress --group-id sg-xtp --security-group-rule-ids sgr-36old'), 'APPLY revoked the stale source'
call check t, logHas(log, 'aws ec2 authorize-security-group-ingress --group-id sg-xtp --protocol 36 --cidr 198.51.100.7/32'), 'APPLY added the workstation'
call SysFileTree base'/cloudctl/var/ops-*.tsv', 'o.', 'FO'
call check t, count(o.1, 'xtp-test-1')=3, 'three ledger rows under the job id (one per slot)'
call check t, countBoth(o.1, 'xtp-test-1', 'NOCHANGE')=1, '... one of them NOCHANGE'

/* all: members without a scope are skipped, the rest planned; rc 2 overall */
call check t, run(base, root, 'xtp all' ws)=2, 'xtp all rc 2 while some members lack a scope'
call check t, has(root'/out', '== ed209b') & has(root'/out', '== ed209k'), '... and still covers every member'

/* 26 Nov 2026 (Claude (Opus 5.5)): removals are named, --add-only removes nothing, errors carry their cause. */
call check t, run(base, root, 'xtp ed209c' ws)=0, 'ed209c PLAN rc 0'
c=section(root'/out', '--  peers-raw', '--  peers-udp')
call check t, pos('REMOVE 203.0.113.77/32', c)>0, 'azure: a full reconcile names the source it removes'
call check t, pos("'--output' 'json'", text(log))=0 | logHas(log, 'nsg rule show'), 'azure: the rule is read as JSON'
call check t, logHas(log, '--name ed209-xtp-peers --output json'), '... with --output json'
u=section(root'/out', '--  peers-udp', '--  ws-raw')
call check t, pos('NO CHANGE', u)>0, 'azure: a rule already holding exactly the wanted sources is left alone'
call check t, run(base, root, 'xtp ed209c --add-only' ws)=0, 'ed209c --add-only PLAN rc 0'
c=section(root'/out', '--  peers-raw', '--  peers-udp')
call check t, pos('REMOVE', c)=0, 'azure --add-only: nothing removed'
call check t, pos('NOTE kept (add-only): 203.0.113.77/32', c)>0, '... the extra source is listed as kept'
call check t, pos("'203.0.113.77/32'", c)>0, '... and is still in the update'
call check t, pos("'20.118.224.14/32'", c)>0, '... next to the added peers'
call check t, run(base, root, 'xtp ed209a --add-only' ws)=0, 'ed209a --add-only PLAN rc 0'
raw=section(root'/out', '--  peers-raw', '--  peers-udp')
call check t, pos('"source":"203.0.113.99\/32"', raw)>0, 'oci --add-only: the stale source stays in the list'
call check t, raw~countStr('"source":"52.146.17.8\/32"')=2, '... duplicates stay too'
call check t, pos('remove 0', raw)>0 & pos('REMOVE', raw)=0, '... and the step removes nothing'
call check t, pos('NOTE kept (add-only): 203.0.113.99/32', raw)>0, '... the kept source is noted'
call SysFileDelete log
call check t, run(base, root, 'xtp ed209d --add-only' ws)=0, 'ed209d --add-only PLAN rc 0'
call check t, \has(root'/out', 'revoke-security-group-ingress'), 'aws --add-only: no revoke'
call check t, has(root'/out', 'NOTE kept (add-only): 203.0.113.99/32'), '... the stale source is noted as kept'
call check t, \logHas(log, '--no-cli-pager'), 'aws: no --no-cli-pager (CLI v1 rejects it)'
call check t, logHas(log, 'aws-pager=[]') & \logHas(log, 'aws-pager=[unset]'), 'aws: every call runs with AWS_PAGER empty'
call check t, run(base, root, 'xtp ed209h --add-only' ws)=0, 'ed209h --add-only PLAN rc 0'
call check t, \has(root'/out', "'DELETE' '/firewalls/fw-h/rules/vfr-old'"), 'vultr --add-only: no DELETE'
call check t, run(base, root, 'xtp ed209e' ws)=0, 'ed209e PLAN rc 0'
call check t, has(root'/out', 'REMOVE 198.51.100.200/32'), 'gcp: a full reconcile names the source it removes'
call check t, run(base, root, 'xtp ed209e --add-only' ws)=0, 'ed209e --add-only PLAN rc 0'
call check t, has(root'/out', 'NOTE kept (add-only): 198.51.100.200/32') & \has(root'/out', 'REMOVE'), 'gcp --add-only: kept, not removed'
call check t, has(root'/out', '198.51.100.200/32,'), '... and still in --source-ranges'
call check t, run(base, root, 'azure firewall reconcile --scope rg-c:nsg-c --rule ed209-xtp-peers --protocol all --sources 198.51.100.9/32 --add-only')=0, 'firewall reconcile takes --add-only'
call check t, has(root'/out', 'NOTE kept (add-only): 193.123.184.140/32') & \has(root'/out', 'REMOVE'), '... and keeps every current source'
call setKeys base, 'ed209i', 'scope=rg-i:nsg-ro'
call check t, run(base, root, 'xtp ed209i' ws)=2, 'read-only HOME: az failure is a STOP, rc 2'
call check t, has(root'/err', 'OSError: [Errno 30] Read-only file system'), '... the reason is the exception, not "Traceback"'
call check t, has(root'/err', 'hint: the provider CLI cannot write its state directory under HOME'), '... with the read-only HOME hint'
call check t, has(root'/err', 'cloudctl: | Traceback'), '... and the stderr tail is in the run log'

call check t, run(base, root, 'xtp show ed209e' ws)=0 & \has(root'/out', 'shares its firewall scope'), 'ed209e and ed209j (scope=default, different GCP projects) do not share a firewall'
e=section(root'/out', '== ed209e', '')
call check t, pos('34.16.115.198/32', e)=0 & pos('34.44.126.133/32', e)>0, '... so ed209e is not its own peer, and ed209j is'
call check t, run(base, root, 'xtp show ed209a' ws)=0 & has(root'/out', 'ed209a shares its firewall scope with ed209b'), 'ed209a and ed209b (one OCI security list) still share'

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

count: procedure
  use strict arg file, needle
  return text(file)~countStr(needle)

countBoth: procedure
  use strict arg file, a, b
  n=0
  do l over text(file)~makeArray('0A'x)
    if pos(a, l)=0 then iterate
    if pos(b, l)>0 then n=n+1
  end
  return n

logHas: procedure
  use strict arg file, needle
  return pos(needle, text(file))>0

section: procedure
  use strict arg file, from, upto
  s=text(file)
  a=pos(from, s)
  if a=0 then return ''
  b=pos(upto, s, a+1)
  if b=0 then return s~substr(a)
  return s~substr(a, b-a)

setKeys: procedure
  use strict arg base, node, ...
  f=base'/cloudctl/etc/machines/'node'.machine'
  do i=3 to arg()
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
  address system 'mkdir -p "'base'/cloudctl" "'base'/repo/packages/oorexx_logging_v0.7" "'root'/fakebin" "'root'/dev4bin"'
  address system 'cp -r "'pkg'/src" "'pkg'/bin" "'pkg'/etc" "'pkg'/tests" "'pkg'/cloudctl.rex" "'base'/cloudctl/"'
  address system 'if [ ! -d "'base'/cloudctl/etc/machines" ]; then cp -r "'base'/cloudctl/tests/fixtures/registry/." "'base'/cloudctl/etc/"; fi'
  address system 'cp "'shim'" "'base'/cloudctl.sh" && chmod +x "'base'/cloudctl.sh" "'base'/cloudctl/tests/fixtures/"*'
  address system 'cp -r "'logPkg'/src" "'base'/repo/packages/oorexx_logging_v0.7/"'
  address system 'for n in az gcloud aws oci vultr-cli; do ln -s "'base'/cloudctl/tests/fixtures/xtp-fake" "'root'/fakebin/$n"; ln -s "'base'/cloudctl/tests/fixtures/cloud-fake" "'root'/dev4bin/$n"; done'
  address system 'ln -s "'base'/cloudctl/tests/fixtures/curl-fake" "'root'/fakebin/curl"'
  return
