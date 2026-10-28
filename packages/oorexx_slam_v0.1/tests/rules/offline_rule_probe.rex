/* Runs the Federation Bank ooRexx engine's validateAdvice on the cases SLAM chose from the rules it
 * read in both languages (the same cases OfflineRuleProbe.java runs on the Java ATM).
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 * Prints one line per case:  CASE <name> <ok|refused> <code>
 */
signal on syntax name onSyntax
call probe 'MAX_EQUAL', 10000, 10000, 'GBP'
call probe 'MAX_PLUS_ONE', 10000, 10001, 'GBP'
call probe 'ZERO', 10000, 0, 'GBP'
call probe 'CURRENCY_LOWER', 10000, 10000, 'gbp'
/* advice that arrives 2 hours late (after expiry): the Java demo bank's rule refuses it; this bank's
   rule looks at when the cash went out instead */
call late 'LATE_DISPENSED_INSIDE', 5
call late 'LATE_DISPENSED_OUTSIDE', 30
exit 0

late: procedure
  use arg name, minutes
  svc = .FederationBankAtmOfflineAuthorityService~new(.nil)
  now = .DateTime~new
  r = svc~issue('OA-' || name, 'RESERVED_ALLOWANCE', 'ATM-IOM-001', 'CUST-1', 'ACC-1', 'GBP', 10000, 'HOLD-1', 'FB-ATM-IOM-DEMO', 3, now)
  dispensed = (now + .TimeSpan~fromMinutes(minutes))~isoDate      /* the authority lasts 10 minutes */
  received = now + .TimeSpan~fromHours(2)
  v = svc~validateAdvice('OA-' || name, 'ATM-IOM-001', 'CUST-1', 'ACC-1', 'GBP', 5000, 'FB-ATM-IOM-DEMO', 3, 'KEY-' || name, 'PHYS-' || name, dispensed, '', 0, received)
  state = 'refused'
  if v~ok then state = 'ok'
  say 'LATE' name state v~code
  return

probe: procedure
  use arg name, allowance, amount, currency
  svc = .FederationBankAtmOfflineAuthorityService~new(.nil)     /* no topic fabric: kept in memory */
  r = svc~issue('OA-' || name, 'RESERVED_ALLOWANCE', 'ATM-IOM-001', 'CUST-1', 'ACC-1', 'GBP', allowance, 'HOLD-1', 'FB-ATM-IOM-DEMO', 3, .DateTime~new)
  if \r~ok then do
    say 'CASE' name 'setup-failed' r~code
    return
  end
  v = svc~validateAdvice('OA-' || name, 'ATM-IOM-001', 'CUST-1', 'ACC-1', currency, amount, 'FB-ATM-IOM-DEMO', 3, 'KEY-' || name, 'PHYS-' || name)
  state = 'refused'
  if v~ok then state = 'ok'
  say 'CASE' name state v~code
  return

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D')
  exit 1

::requires 'FederationBankAtmGateway.cls'
