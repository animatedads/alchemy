/* send.rex - the capturing side of the alchemy_rto_core dev4 tests.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5).  24 Nov 2026.
 *   rexx send.rex WORKDIR     writes plain.json, hmac.json and ed25519.json */
parse arg work
if work == '' then do; say 'usage: rexx send.rex WORKDIR'; exit 2; end
j = .RTO2CountJob~new('C1', 'MI-A', 'ACTIVE', .nil)
call activateFirst j
j~commitLocalValue(41)
j~commitLocalValue(42)
say 'sender: value' j~value 'committedSequence' j~committedSequence
call put work'/plain.json', .AlchemyRTO~capture(j, j~committedSequence, j~committedSequence)~document~toWire
call put work'/hmac.json', .AlchemyRTO~capture(j, 2, 2, .AlchemyRTOHmacSealer~new('k-tom-1', '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff'))~document~toWire
-- RFC 8032 section 7.1, test 1: a published key, never a real one
call put work'/ed25519.json', .AlchemyRTO~capture(j, 2, 2, .AlchemyRTOEd25519Sealer~new('rfc8032-t1', '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60'))~document~toWire
say 'sender: 3 envelopes written'
exit 0

activateFirst: procedure
  use arg job
  job~negotiateRole('ACTIVE', 1)
  return
put: procedure
  use arg path, text
  s = .Stream~new(path); s~open('write replace'); s~charOut(text); s~close
  return

::requires 'RTO2CountJob.cls'
::requires 'AlchemyRTO.cls'
