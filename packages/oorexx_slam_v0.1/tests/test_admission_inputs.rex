/* Admission inputs: known literal type refusals and malformed path refusal.
 * Architecture: Tom Dyer. Coding: ChatGPT GPT-6, 2026-10-29.
 * Run: REXX_PATH=src:vendor/rx2cpp rexx tests/test_admission_inputs.rex <crypto.cls>
 * The exploratory run() is intentionally unchanged. */
signal on syntax name testFailed
parse arg cryptoFile
if cryptoFile == '' then do
  say 'usage: test_admission_inputs.rex path/to/crypto.cls'
  exit 2
end
checks = 0
c = .SlamComposer~new
call c~lift(cryptoFile, 'rx_pow_mod', 'POWMOD')

r = c~runAdmitted('not an Array')
call blocked r, 'non-Array path'
r = c~runAdmitted(.array~of('not a step Array'))
call blocked r, 'non-Array step'
r = c~runAdmitted(.array~of(.array~of('POWMOD')))
call blocked r, 'step missing argument Array'
r = c~runAdmitted(.array~of(.array~of('POWMOD', 23)))
call blocked r, 'non-Array arguments'
r = c~runAdmitted(.array~of(.array~of('NO_SUCH_UNIT', .array~new)))
call blocked r, 'unknown alias'

r = c~runAdmitted(.array~of(.array~of('POWMOD', .array~of('not-a-number', 3, 1000003))))
call blocked r, 'text where base needs NUMBER'
call check r['PREDICTION']~pos('needs NUMBER') > 0, 'literal type refusal says why'

/* In ooRexx, numeric text is a legitimate numeric value. */
r = c~runAdmitted(.array~of(.array~of('POWMOD', .array~of('2', 3, 1000003))))
call check r['STATUS'] == 'OK' & r['RESULT'] = 8, 'numeric text remains admissible'

/* A literal text refusal must not change the observational run API. */
r = c~admit(.array~of(.array~of('POWMOD', .array~of('not-a-number', 3, 1000003))))
call check \r['FEASIBLE'], 'admission predicts the invalid literal without executing'

say 'ADMISSION INPUTS: PASS (' || checks || ' checks)'
exit 0

blocked: procedure expose checks
  use arg r, label
  call check r['STATUS'] == 'BLOCKED' & \r['FEASIBLE'] & r['TRACE']~items == 0 & \r~hasIndex('RESULT'), label 'blocked before execution'
  return

check: procedure expose checks
  use arg ok, label
  checks += 1
  if ok then say 'PASS' label
  else do
    say 'FAIL' label
    exit 1
  end
  return

testFailed:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D')
  exit 1

::requires 'SlamCompose.cls'
