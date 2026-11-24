/* recv.rex - the receiving side of the alchemy_rto_core dev4 tests, in its own
 * process, without the sender's objects.  Every attack the dev3 probe got
 * through must now be refused, with its code.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5).  24 Nov 2026.
 *   rexx recv.rex WORKDIR */
parse arg work
if work == '' then do; say 'usage: rexx recv.rex WORKDIR'; exit 2; end
fails = 0
hmac = .AlchemyRTOHmacSealer~new('k-tom-1', '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff')
otherHmac = .AlchemyRTOHmacSealer~new('k-other', '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff')
ed = .AlchemyRTOEd25519Verifier~new~trustKey('rfc8032-t1', 'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a')
edWrong = .AlchemyRTOEd25519Verifier~new~trustKey('rfc8032-t1', '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c')

-- 1. the honest round trip: state arrives, the object stays inert
t = spare('C1', 'MI-A')
call expectOk 'plain', t, .nil, 'round trip'
call check t~value = 42 & t~committedValue = 42, 'state arrived: value 42, committed 42'
call check t~rtoLifecycleState == 'RECONSTRUCTED', 'lifecycle recorded: RECONSTRUCTED (was not recorded in dev3)'
call check t~rtoState \== 'ACTIVE', 'reconstruction is inert: not ACTIVE ('t~rtoState')'
.AlchemyRTOLifecycle~new~bind(t, .Directory~new)
.AlchemyRTOLifecycle~new~activate(t, 2)
call check t~rtoLifecycleState == 'ACTIVE', 'bind then activate: lifecycle ACTIVE'

-- 2. the attacks the dev3 probe got through
call expectRefused 'plain', spare('OTHER', 'MI-Z'), .nil, 'RTO_WRONG_TARGET', 'envelope applied to another object'
call expectRefused 'plain', spare('C1', 'MI-A'), .nil, 'RTO_SCHEMA', 'foreign schema', 'schema', 'not.rto/9'
call expectRefused 'plain', spare('C1', 'MI-A'), .nil, 'RTO_DIGEST', 'state changed after capture', 'value', 999999
call expectRefused 'plain', ahead('C1', 'MI-A', 3), .nil, 'RTO_STALE', 'an older capture over newer state'

-- 3. the edges
call expectRefused 'plain', spare('C1', 'MI-A'), .nil, 'RTO_DIGEST', 'no digest at all', 'digest', ''
call expectRefused 'plain', spare('C1', 'MI-A'), .nil, 'RTO_SEQUENCE', 'sequence not a number', 'sequence', 'x'
call expectRefused 'plain', spare('C1', 'MI-A'), .nil, 'RTO_SEQUENCE', 'committed after sequence', 'committedSequence', 9
-- a digest alone detects damage, not an attacker: one who recomputes it gets through
-- without a verifier, and is stopped by any verifier
call expectOk 'plain', spare('C1', 'MI-A'), .nil, 'forged digest with no verifier is accepted (by design: no key, no authentication)', 'committedValue', 5000, 'reseal'
call expectRefused 'plain', spare('C1', 'MI-A'), hmac, 'RTO_SEAL', 'a verifier requires a seal'

-- 4. HMAC-SHA-512, a shared key in one trust domain
call expectOk 'hmac', spare('C1', 'MI-A'), hmac, 'HMAC seal verifies'
call expectRefused 'hmac', spare('C1', 'MI-A'), hmac, 'RTO_SEAL', 'HMAC: state changed and digest recomputed', 'committedValue', 5000, 'reseal'
call expectRefused 'hmac', spare('C1', 'MI-A'), otherHmac, 'RTO_SEAL', 'HMAC: key not trusted here'

-- 5. Ed25519, the sender's own key; the receiver holds only its public key
call expectOk 'ed25519', spare('C1', 'MI-A'), ed, 'Ed25519 seal verifies with the public key'
call expectRefused 'ed25519', spare('C1', 'MI-A'), edWrong, 'RTO_SEAL', 'Ed25519: another public key'
call expectRefused 'ed25519', spare('C1', 'MI-A'), ed, 'RTO_SEAL', 'Ed25519: state changed and digest recomputed', 'value', 7, 'reseal'

if fails > 0 then do; say 'FAIL alchemy_rto_core dev4:' fails 'failed'; exit 1; end
say 'PASS alchemy_rto_core dev4'
exit 0

/* one envelope from disk, perhaps altered: field, value, and 'reseal' to recompute the digest */
load: procedure expose work
  use arg name, field = '', newValue = '', reseal = ''
  s = .Stream~new(work'/'name'.json'); text = s~charIn(1, s~chars); s~close
  env = .AlchemyRTOEnvelope~fromWire(text)
  select
    when field == '' then nop
    when field == 'value' | field == 'committedValue' then env~objects[env~root][field] = newValue
    otherwise env~send(field'=', newValue)
  end
  if reseal == 'reseal' then env~digest = env~computeDigest
  return .AlchemyRTOCaptureResult~of(env)

expectOk:
  use arg name, target, verifier, label, field = '', newValue = '', reseal = ''
  signal on syntax name okFailed
  .AlchemyRTO~reconstruct(load(name, field, newValue, reseal), target, verifier)
  signal off syntax
  call check .true, label
  return
okFailed:
  call check .false, label '(refused:' condition('O')~additional[1]')'
  return

expectRefused:
  use arg name, target, verifier, code, label, field = '', newValue = '', reseal = ''
  before = target~value
  signal on syntax name refused
  .AlchemyRTO~reconstruct(load(name, field, newValue, reseal), target, verifier)
  signal off syntax
  call check .false, label '(accepted; want' code')'
  return
refused:
  text = condition('O')~additional[1]
  call check text~startsWith(code) & target~value = before, label '->' text~left(70)
  return

spare: procedure
  use arg cluster, instance
  return .RTO2CountJob~new(cluster, instance, 'SPARE', .nil)
ahead: procedure
  use arg cluster, instance, commits
  t = .RTO2CountJob~new(cluster, instance, 'ACTIVE', .nil)
  t~negotiateRole('ACTIVE', 1)
  do i = 1 to commits; t~commitLocalValue(100 + i); end
  return t
check:
  use arg ok, label
  if ok then say 'PASS' label
  else do; say 'FAIL' label; fails += 1; end
  return

::requires 'RTO2CountJob.cls'
::requires 'AlchemyRTO.cls'
