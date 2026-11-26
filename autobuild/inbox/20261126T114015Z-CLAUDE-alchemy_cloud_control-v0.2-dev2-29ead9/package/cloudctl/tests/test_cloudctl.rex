/* test_cloudctl.rex -- Cloud Control acceptance tests.  Touches no cloud.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 7 November 2026.
 * Fixtures: tests/fixtures/cloud-fake and fake-gcloud-account.sh are dev4's own (alchemy_cloud_control
 * v0.1-dev4, Codex), unchanged: one fake answers as az, gcloud, aws, oci and vultr-cli and logs every call.
 * Cases 1-37 are dev4's tests/run.sh cases (mutations now carry --apply: PLAN is the default here).
 *
 * usage: rexx test_cloudctl.rex CLOUDCTL_DIR SHIM LOGGING_PACKAGE_DIR
 */
parse arg pkg shim logPkg .
if logPkg='' then do
  say 'usage: rexx test_cloudctl.rex CLOUDCTL_DIR SHIM LOGGING_PACKAGE_DIR'
  exit 4
end
address system 'mktemp -d' with output stem d.
root=d.1
base=root'/autobuild'
call build root, base, pkg, shim, logPkg
log=root'/provider.log'
call env 'CLOUDCTL_PROVIDER_LOG', log
call env 'ALCHEMY_GCLOUD_ACCOUNT_WRAPPER', base'/cloudctl/tests/fixtures/fake-gcloud-account.sh'
call env 'PATH', root'/fakebin:'value('PATH',,'ENVIRONMENT')
call lineout root'/vultr.key', 'TESTKEY-123'; call lineout root'/vultr.key'; address system 'chmod 600 "'root'/vultr.key"'; call env 'VULTR_API_KEY_FILE', root'/vultr.key'
t=.directory~new; t~pass=0; t~fail=0

/* 1. machine list: stdout is the provider's JSON and nothing else */
ctx=.directory~new
ctx['azure']=''; ctx['gcp']='--account bashqueue --project p'; ctx['aws']='--region eu-west-2'
ctx['oci']='--compartment ocid1.compartment.fake --region uk-london-1'; ctx['vultr']=''
do p over .array~of('azure', 'gcp', 'aws', 'oci', 'vultr')
  rc=run(base, root, p 'machine list' ctx[p])
  call check t, rc=0, p 'machine list rc 0'
  call check t, isJson(root'/out'), p 'machine list stdout is valid JSON'
end

/* 2-8. reboot */
call check t, run(base, root, 'azure machine reboot --machine /subscriptions/s/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/az-one --apply')=0, 'azure reboot'
call check t, run(base, root, 'gcp machine reboot --machine europe-west2-a/gcp-one --account bashqueue --project p --apply')=0, 'gcp reboot (zone/name handle)'
call check t, run(base, root, 'aws machine reboot --machine i-123 --region eu-west-2 --apply')=0, 'aws reboot'
call check t, run(base, root, 'oci machine reboot --machine ocid1.instance.fake --region uk-london-1 --apply')=0, 'oci reboot'
call check t, run(base, root, 'vultr machine reboot --machine vultr-123 --apply')=0, 'vultr reboot'
call check t, logHas(log, 'oci compute instance action --instance-id ocid1.instance.fake --action SOFTRESET'), 'oci reboot is SOFTRESET'
call check t, \logHasBoth(log, 'oci compute instance action', '--compartment-id'), 'oci action carries no --compartment-id'
call check t, logHas(log, 'gcloud compute instances reset gcp-one --zone europe-west2-a --quiet --project p'), 'gcp reboot is reset, zone split from the handle'

/* 9. start, stop, destroy */
do a over .array~of('start', 'stop', 'destroy')
  extraA=''; extraG=''
  if a='destroy' then do
    extraA='--confirm i-123'; extraG='--confirm europe-west2-a/gcp-one'
  end
  call check t, run(base, root, 'aws machine' a '--machine i-123 --region eu-west-2 --apply' extraA)=0, 'aws' a
  call check t, run(base, root, 'gcp machine' a '--machine europe-west2-a/gcp-one --account bashqueue --project p --apply' extraG)=0, 'gcp' a
end

/* 10-14. create */
call check t, run(base, root, 'azure machine create --group rg --name n --image img --size small --apply')=0, 'azure create'
call check t, run(base, root, 'gcp machine create --account bashqueue --project p --name n --zone z --image img --size small --apply')=0, 'gcp create'
call check t, run(base, root, 'aws machine create --name n --image ami-x --size t3.nano --region eu-west-2 --apply')=0, 'aws create'
call check t, run(base, root, 'oci machine create --name n --compartment c --availability-domain ad --subnet s --image i --size shape --region uk-london-1 --apply')=0, 'oci create'
call check t, run(base, root, 'vultr machine create --name n --region lhr --size vc2 --os 1743 --apply')=0, 'vultr create'

/* 15-29. firewall list, allow, revoke */
fw=.array~new
fw~append('azure firewall list --scope rg:nsg')
fw~append('azure firewall allow --scope rg:nsg --rule ssh --protocol tcp --port 22 --source 203.0.113.0/24 --apply')
fw~append('azure firewall revoke --scope rg:nsg --rule ssh --apply')
fw~append('gcp firewall list --scope default --account bashqueue --project p')
fw~append('gcp firewall allow --scope default --account bashqueue --project p --rule ssh --protocol tcp --port 22 --source 203.0.113.0/24 --apply')
fw~append('gcp firewall revoke --account bashqueue --project p --scope default --rule ssh --apply')
fw~append('aws firewall list --scope sg-123 --region eu-west-2')
fw~append('aws firewall allow --scope sg-123 --region eu-west-2 --protocol tcp --port 22 --source 203.0.113.0/24 --apply')
fw~append('aws firewall revoke --scope sg-123 --region eu-west-2 --rule sgr-123 --apply')
fw~append('oci firewall list --scope ocid1.nsg.fake --region uk-london-1')
fw~append('oci firewall allow --scope ocid1.nsg.fake --region uk-london-1 --protocol tcp --port 22 --source 203.0.113.0/24 --apply')
fw~append('oci firewall revoke --scope ocid1.nsg.fake --region uk-london-1 --rule rule1 --apply')
fw~append('vultr firewall list --scope fw-123')
fw~append('vultr firewall allow --scope fw-123 --protocol tcp --port 22 --source 203.0.113.0/24 --apply')
fw~append('vultr firewall revoke --scope fw-123 --rule rule1 --apply')
do c over fw
  call check t, run(base, root, c)=0, c~subword(1,3)
end

/* 30-34. reconcile */
call SysFileDelete log
s='--sources 198.51.100.0/24,192.0.2.0/24'
call check t, run(base, root, 'azure firewall reconcile --scope rg:nsg --rule ssh --protocol tcp --port 22' s '--apply')=0, 'azure reconcile'
call check t, run(base, root, 'gcp firewall reconcile --scope default --account bashqueue --project p --rule ssh --protocol tcp --port 22' s '--apply')=0, 'gcp reconcile'
call check t, run(base, root, 'aws firewall reconcile --scope sg-123 --region eu-west-2 --rule ssh --protocol tcp --port 22' s '--apply')=0, 'aws reconcile'
call check t, run(base, root, 'oci firewall reconcile --scope ocid1.nsg.fake --region uk-london-1 --rule ssh --protocol tcp --port 22' s '--apply')=0, 'oci reconcile'
call check t, run(base, root, 'vultr firewall reconcile --scope fw-123 --rule ssh --protocol tcp --port 22' s '--apply')=0, 'vultr reconcile'
call check t, logHasBoth(log, 'az network nsg rule update', '--source-address-prefixes 198.51.100.0/24 192.0.2.0/24'), 'azure reconcile updates the whole source list'
call check t, logHasBoth(log, 'compute firewall-rules update ssh', '--source-ranges 198.51.100.0/24,192.0.2.0/24'), 'gcp reconcile updates source ranges'
call check t, logHas(log, 'aws ec2 revoke-security-group-ingress --group-id sg-123 --security-group-rule-ids sgr-123'), 'aws reconcile removes the stale source'
call check t, logHas(log, 'aws ec2 authorize-security-group-ingress --group-id sg-123 --protocol tcp --cidr 198.51.100.0/24'), 'aws reconcile adds a new source'
call check t, logHas(log, 'oci network nsg rules remove --nsg-id ocid1.nsg.fake'), 'oci reconcile removes'
call check t, logHas(log, 'oci network nsg rules add --nsg-id ocid1.nsg.fake'), 'oci reconcile adds'
call check t, logHas(log, 'curl DELETE https://api.vultr.com/v2/firewalls/fw-123/rules/vfr-123'), 'vultr reconcile removes (REST)'
call check t, logHasBoth(log, 'curl POST https://api.vultr.com/v2/firewalls/fw-123/rules', '"subnet":"198.51.100.0"'), 'vultr reconcile adds (REST)'
call check t, logHasBoth(log, '"subnet":"198.51.100.0"', '"subnet_size":24'), '... with the prefix as subnet_size'
call check t, logHas(log, 'auth=stdin') & \logHas(log, 'auth=MISSING'), 'vultr: every call got the key on stdin'
call check t, \logHas(log, 'TESTKEY'), 'vultr: the key is in no command line'

/* 35-37. refusals from dev4 */
call check t, run(base, root, "aws firewall reconcile --scope sg-123 --region eu-west-2 --protocol tcp --port 22 --sources ''")=2, 'empty reconcile source set refused (2)'
call check t, fileHas(root'/err', 'missing --sources'), '... with a reason'
call check t, run(base, root, 'gcp machine list --project p')=2, 'gcp without an account refused (2)'
call check t, fileHas(root'/err', 'explicit --account'), '... names the explicit account rule'
call check t, run(base, root, 'aws machine list --token nope')=2, 'secret option refused (2)'
call check t, fileHas(root'/err', 'secret-bearing'), '... names the secret rule'

/* 38+. new behaviour */
call SysFileDelete log
call check t, run(base, root, 'aws machine reboot --machine i-123 --region eu-west-2')=0, 'mutation without --apply is a PLAN (rc 0)'
call check t, fileHas(root'/out', 'CHANGE') & fileHas(root'/out', 'PLANNED'), '... shows the CHANGE step and PLANNED'
call check t, \logHas(log, 'reboot-instances'), '... and nothing reached the provider'
call check t, run(base, root, 'aws machine destroy --machine i-123 --region eu-west-2 --apply')=2, 'destroy without --confirm refused'
call check t, run(base, root, 'aws machine destroy --machine i-123 --region eu-west-2 --apply --confirm i-999')=2, 'destroy with the wrong --confirm refused'
call check t, run(base, root, 'aws machine list --region eu-west-2 --colour blue')=2, 'unknown option refused'
call check t, run(base, root, 'aws firewall allow --scope sg-1 --region r --protocol tcp --source 1.2.3.0/24 --port 70000 --apply')=2, 'port out of range refused'
call check t, run(base, root, 'aws firewall allow --scope sg-1 --region r --protocol tcp --source 1.2.3.4 --port 22 --apply')=0, 'a bare IPv4 address passes the CIDR rule'
call check t, run(base, root, 'aws firewall allow --scope sg-1 --region r --protocol tcp --source 1.2.3 --port 22 --apply')=2, 'a three-octet address refused'
call check t, run(base, root, 'aws firewall allow --scope sg-1 --region r --protocol tcp --source 1.2.3.999/24 --port 22 --apply')=2, 'a bad CIDR refused'
call check t, run(base, root, 'vultr restart ed209k --apply')=0, 'old "vultr restart ed209k" works'
call check t, logHas(log, 'curl POST https://api.vultr.com/v2/instances/'regValue(base, 'ed209k', 'handle')'/reboot'), '... through the machine registry handle (REST)'
okKey=value('VULTR_API_KEY_FILE',,'ENVIRONMENT')
address system 'chmod 644 "'okKey'"'
call check t, run(base, root, 'vultr machine list')=2 & fileHas(root'/err', 'chmod 600 it'), 'vultr: a key file readable by others refused'
address system 'chmod 600 "'okKey'"'
call env 'VULTR_API_KEY_FILE', root'/no-such.key'
call check t, run(base, root, 'vultr machine list')=2 & fileHas(root'/err', 'no Vultr API key'), 'vultr: no key file refused before any call'
call env 'VULTR_API_KEY_FILE', okKey
call check t, run(base, root, 'gcp machine reboot --machine ed209e --apply')=0, 'gcp reboot by registry name'
call check t, logHas(log, 'gcloud compute instances reset instance-20260906-161857 --zone us-central1-a --quiet --project 'regValue(base, 'ed209e', 'project')), '... account, handle, zone and project from the registry'
spot='gcp machine create --account bashqueue --name s1 --zone us-central1-a --size e2-small --image-family debian-12 --image-project debian-cloud --provisioning-model SPOT --max-run-duration 80m --instance-termination-action DELETE --preemption-notice-duration 120s'
call check t, run(base, root, spot '--apply')=0, 'Spot create with an 80 minute limit'
call check t, logHas(log, '--provisioning-model SPOT --max-run-duration 80m --instance-termination-action DELETE --preemption-notice-duration 120s'), '... carries the Spot flags'
call check t, run(base, root, spot~changeStr('120s', '60s'))=2, 'preemption notice other than 0s/120s refused'
std='gcp machine create --account bashqueue --name s2 --zone z --size e2-small --image-family debian-12 --max-run-duration 80m'
call check t, run(base, root, std)=2, 'run limit on a standard VM without a termination action refused'

/* a wrapper that fails silently (gcloud-account.sh under set -e) must not pass silently or read as "absent" */
okWrapper=value('ALCHEMY_GCLOUD_ACCOUNT_WRAPPER',,'ENVIRONMENT')
call lineout root'/silent-wrapper.sh', '#!/bin/sh'
call lineout root'/silent-wrapper.sh', 'exit 3'
call lineout root'/silent-wrapper.sh'
address system 'chmod +x "'root'/silent-wrapper.sh"'
call env 'ALCHEMY_GCLOUD_ACCOUNT_WRAPPER', root'/silent-wrapper.sh'
call check t, run(base, root, 'gcp machine list --account bashqueue')=3, 'silent wrapper failure: rc 3 passed through'
call check t, fileHas(root'/err', 'cloudctl: FAILED rc=3'), '... and said so on stderr'
call check t, fileHas(root'/err', 'cloudctl: > READ'), 'every provider call is announced on stderr'
call check t, run(base, root, 'gcp firewall reconcile --scope default --account bashqueue --rule ssh --protocol tcp --port 22 --sources 198.51.100.0/24')=2, 'reconcile with an unreadable rule state refused (2)'
call check t, fileHas(root'/err', 'cannot tell whether gcp firewall rule ssh exists: rc=3'), '... not planned as a create'
call check t, \fileHas(root'/out', 'firewall-rules'' ''create'), '... no create step in the plan'
call env 'ALCHEMY_GCLOUD_ACCOUNT_WRAPPER', okWrapper
address system '"'base'/cloudctl.sh" machines > "'root'/machines.out" 2>&1'
call check t, \fileHas(root'/machines.out', 'The NIL object'), 'machines: blank fields print blank'
call check t, fileHas(root'/machines.out', 'clouvider'), 'machines: provider not truncated'

/* ledger, hours, check, events */
call SysFileTree base'/cloudctl/var/ops-*.tsv', 'o.', 'FO'
ops=lines(o.1)
call check t, ops~items>55, 'every operation in the ops ledger ('ops~items-1 'rows)'
refused=0
do l over ops
  if pos('09'x'REFUSED'||'09'x, l)>0 then refused=refused+1
end
call check t, refused>=8, 'refusals recorded in the ledger ('refused')'
m=lines(base'/cloudctl/var/machines.tsv')
call check t, m~items>10, 'machine lifecycle events recorded ('m~items-1')'
address system '"'base'/cloudctl.sh" hours > "'root'/hours.out" 2>&1'
if \fileHas(root'/hours.out', 'ed209k') then address system 'cat "'root'/hours.out"'
call check t, fileHas(root'/hours.out', 'ed209k'), 'hours report lists ed209k'
address system '"'base'/cloudctl.sh" check gcp machine create --account bashqueue --name x --zone z --size s > "'root'/check.out" 2>&1'
call check t, rc=2, 'check exits 2 on a STOP'
call check t, fileHas(root'/check.out', 'STOP gcpimage'), 'check prints the STOP bucket'
call SysFileTree base'/cloudctl/var/events-*.log', 'e.', 'FO'
call check t, fileHas(e.1, 'END job=') & fileHas(e.1, 'RULE job='), 'events log has RULE and END events'

say 'RESULT pass='t~pass 'fail='t~fail
address system 'rm -rf "'root'"'
if t~fail>0 then exit 1
exit 0

/* ------------------------------------------------------------------------------------------------------------ */
run: procedure
  use strict arg base, root, argText
  address system '"'base'/cloudctl.sh"' argText '</dev/null >"'root'/out" 2>"'root'/err"'
  return rc

env: procedure
  use strict arg name, val
  call value name, val, 'ENVIRONMENT'
  return

lines: procedure
  use strict arg file
  a=.array~new
  if \SysFileExists(file) then return a
  s=.stream~new(file)
  s~open('read')
  do while s~lines>0
    a~append(s~linein)
  end
  s~close
  return a

fileHas: procedure
  use strict arg file, text
  return pos(text, lines(file)~makeString('L', '0A'x))>0

logHas: procedure
  use strict arg file, text
  do l over lines(file)
    if pos(text, l)>0 then return .true
  end
  return .false

logHasBoth: procedure
  use strict arg file, a, b
  do l over lines(file)
    if pos(a, l)>0 then do
      if pos(b, l)>0 then return .true
    end
  end
  return .false

isJson: procedure
  use strict arg file
  text=lines(file)~makeString('L', ' ')
  if text='' then return .false
  signal on syntax name notJson
  doc=.json~new~fromJson(text)
  return .true
notJson:
  return .false

/* A value from the machine registry the test copy uses (the live one, or tests/fixtures/registry). */
regValue: procedure
  use strict arg base, node, key
  v=''
  s=.stream~new(base'/cloudctl/etc/machines/'node'.machine')
  do l over s~arrayIn          /* not lines(): this test has its own lines routine */
    parse var l k '=' val
    if k=key then v=val
  end
  s~close
  return v

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
  address system 'mkdir -p "'base'/cloudctl" "'base'/repo/packages/oorexx_logging_v0.7" "'root'/fakebin"'
  address system 'cp -r "'pkg'/src" "'pkg'/bin" "'pkg'/etc" "'pkg'/tests" "'pkg'/cloudctl.rex" "'base'/cloudctl/"'
  address system 'if [ ! -d "'base'/cloudctl/etc/machines" ]; then cp -r "'base'/cloudctl/tests/fixtures/registry/." "'base'/cloudctl/etc/"; fi'
  address system 'cp "'shim'" "'base'/cloudctl.sh" && chmod +x "'base'/cloudctl.sh" "'base'/cloudctl/tests/fixtures/"*'
  address system 'cp -r "'logPkg'/src" "'base'/repo/packages/oorexx_logging_v0.7/"'
  address system 'for n in az gcloud aws oci vultr-cli; do ln -s "'base'/cloudctl/tests/fixtures/cloud-fake" "'root'/fakebin/$n"; done'
  address system 'ln -s "'base'/cloudctl/tests/fixtures/curl-fake" "'root'/fakebin/curl"'
  return

::requires 'json.cls'
