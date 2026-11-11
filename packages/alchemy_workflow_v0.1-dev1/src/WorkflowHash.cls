/* WorkflowHash.cls - Alchemy Workflow v0.1-dev1: SHA-256 for receipts and tree hashes, through the estate's
 * crypto v0.8.3 with its Foreign Runtime / OpenSSL provider (Tom Dyer, 10 Nov 2026: "you can hash using
 * foreign runtime and crypto. it already does it").
 *
 *   .WorkflowHash~available    .true when the provider is installed and proved on a known answer
 *   .WorkflowHash~why          why it is not ('' when it is)
 *   .WorkflowHash~sha256(s)    lowercase hex
 *   .WorkflowHash~file(path)   the SHA-256 of a file's bytes
 *
 * The workflow never falls back to crypto's pure-ooRexx path (about 1.2 KB/s, measured 10 Nov): without
 * the provider a receipt says it is unhashed and why, and the ledger cannot recognise a resubmission.
 *
 * Needs on REXX_PATH: oorexx_crypto_v0.8.3/src, runtime_reference_v0.4/src,
 * oorexx_foreign_runtime_v0.22.6/rexx; on LD_LIBRARY_PATH the Foreign Runtime build and
 * oorexx_crypto_v0.8.3/native (bin/workflow_env.sh sets both).
 *
 * Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-11-11 (the pattern of the flight planner's FpHash).
 */
::class WorkflowHash public
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'

::method init class
  expose state why
  state = ''
  why = ''

::method available class
  expose state
  if state == '' then self~install
  return state == 'ok'

::method why class
  expose state why
  if state == '' then self~install
  return why

::method sha256 class
  use strict arg s
  if \self~available then raise syntax 98.900 array('Workflow hash: the Foreign Runtime provider is not installed:' self~why)
  return .CryptoHash~hashString(s, 'SHA256')

::method file class
  use strict arg path
  s = .stream~new(path)
  if s~open('read shareread') \= 'READY:' then raise syntax 98.900 array('Workflow hash: cannot read' path)
  body = s~charIn(1, s~chars)
  s~close
  return self~sha256(body)

::method install class
  expose state why
  signal on syntax name failed
  /* loaded here, not by ::requires, so a checkout without crypto still runs, unhashed */
  .context~package~loadPackage('CryptoForeignRuntimeProvider.cls')
  .CryptoForeignRuntimeInstaller~install
  d = .CryptoHash~hashString('abc', 'SHA256')
  e = .RuntimeImplementationSwitch~broker~lastEvidence
  if d \== 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad' then do
    why = 'known-answer digest differs'
    state = 'off'
    return
  end
  if e~providerId \== 'foreign.openssl.crypto' then do
    why = 'provider did not run (' || e~providerId e~outcomeCode || ')'
    state = 'off'
    return
  end
  state = 'ok'
  return
failed:
  c = condition('O')
  why = 'install failed: ' || c['MESSAGE']
  state = 'off'
  return
