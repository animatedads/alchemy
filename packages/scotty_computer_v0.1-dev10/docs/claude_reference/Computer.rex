/* Computer.rex - one-shot front door to the Computer intentions.              */
/* Architecture: Tom Dyer.  Coding: Claude Sonnet 5.5.  UNTESTED first cut.     */
/* Run it through the ./Computer wrapper, which sets REXX_PATH.                 */
/* Exit codes: 0 OK, 1 FAIL, 3 CONFIRM needed (nothing executed),              */
/*             4 NEEDS more detail (nothing executed), 2 internal error.        */
signal on syntax name SyntaxTrap

parse arg commandline
commandline = space(strip(commandline))
lc = lower(commandline)
if left(lc, 9) == "computer " then do
  commandline = strip(substr(commandline, 10))
  lc = lower(commandline)
end

if commandline == "" then do
  say "FAIL intent=none reason=no command given"
  say .ComputerFactory~catalogue
  exit 1
end
if lc == "help" | lc == "list" then do
  say .ComputerFactory~catalogue
  exit 0
end

kit = .ComputerKit~new
service = .ComputerFactory~build(kit)

if left(lc, 8) == "confirm " then do
  token = word(commandline, 2)
  phrase = kit~pendingTake(token)
  if phrase == "" then do
    kit~receipt("FAIL intent=confirm reason=unknown, used or malformed token: " || token)
    exit 1
  end
  decision = service~input(phrase)
  if decision~status \== "CONFIRM" then do
    kit~receipt("FAIL intent=confirm reason=the parked command no longer needs confirmation: " || phrase)
    exit 1
  end
  decision = service~input("yes")
end
else decision = service~input(commandline)

status = decision~status
select
  when status == "READY" then do
    outcome = service~dispatch(decision)
    if outcome == "OK" then exit 0
    exit 1
  end
  when status == "CONFIRM" then do
    token = kit~pendingSave(commandline)
    say "CONFIRM intent=" || decision~registration~id "meaning=" || decision~registration~phrase
    slotSupplier = decision~slots~supplier
    do while slotSupplier~available
      say "  " || slotSupplier~index || "=" || slotSupplier~item~value
      slotSupplier~next
    end
    say "NOT EXECUTED. To proceed, type exactly:"
    say "Computer confirm" token
    exit 3
  end
  when status == "CLARIFY" then do
    say "NEEDS intent=" || decision~registration~id "question=" || decision~question
    say "NOT EXECUTED. Re-issue the complete command with the missing detail."
    exit 4
  end
  otherwise do
    kit~receipt("FAIL intent=unknown reason=" || decision~question)
    say .ComputerFactory~catalogue
    exit 1
  end
end
exit 1

SyntaxTrap:
  say "FAIL intent=internal reason=Rexx error rc="rc "sigl="sigl "condition="condition("C") "desc="condition("D")
  exit 2

::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
::requires "ComputerIntentions.cls"
