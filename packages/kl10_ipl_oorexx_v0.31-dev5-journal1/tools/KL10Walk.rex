/* Generic architectural walker for a frozen KL10 state.
 *
 * Usage:
 *   rexx KL10Walk.rex state.kl10state step [n]
 *   rexx KL10Walk.rex state.kl10state until <predicate> [max]
 *
 * Predicates:
 *   pc=OOOOOO
 *   mnemonic=NAME
 *   io.device=NAME
 *   io.function=NAME
 *   paging.enable-request
 *   unsupported
 *
 * Predicates inspect cpu~preview: the next instruction is observed before it
 * becomes execution. No MTBOOT-specific address or loop knowledge lives here.
 */
numeric digits 30
parse arg statePath command predicate maxSteps
if statePath = "" | command = "" then do
  call usage
  exit 2
end

state=.KL10State~new
cpu=state~load(statePath)

select
  when command = "step" then do
    if predicate = "" then count=1
    else count=predicate
    if \datatype(count,"W") | count < 0 then do
      say "step count must be a non-negative integer"
      exit 2
    end
    do i=1 to count
      call printPreview cpu~preview
      tr=cpu~step
      call printTrace tr,cpu
    end
    call printPreview cpu~preview
  end

  when command = "until" then do
    if predicate = "" then do
      say "until requires an architectural predicate"
      exit 2
    end
    if maxSteps = "" then maxSteps=1000000
    if \datatype(maxSteps,"W") | maxSteps < 1 then do
      say "max must be a positive integer"
      exit 2
    end

    stepped=0
    do forever
      proposal=cpu~preview
      if predicateMatches(predicate,proposal) then do
        say "MATCH after" stepped "steps"
        call printPreview proposal
        leave
      end

      if predicate = "unsupported" then do
        signal on syntax name unsupportedReached
        tr=cpu~step
        signal off syntax
      end
      else tr=cpu~step

      stepped=stepped+1
      if stepped >= maxSteps then do
        say "NO MATCH: maximum" maxSteps "steps reached"
        call printPreview cpu~preview
        exit 3
      end
    end
  end

  otherwise do
    call usage
    exit 2
  end
end
exit 0

unsupportedReached:
  signal off syntax
  say "MATCH after" stepped "steps"
  say "unsupported proposal:"
  call printPreview proposal
  say "reason:" condition("D")
  exit 0

predicateMatches: procedure
  use arg predicate,p
  if predicate = "paging.enable-request" then do
    if p["format"] \= "IO" | p["deviceName"] \= "PAG" | p["ioFunction"] \= 4 then return 0
    e=p["effectiveAddress"]
    if e = .nil then return 0
    /* PAG CONO bit 020000 enables translation; 040000 selects TOPS-20 mode. */
    return ((e % (2**13)) // 2) | ((e % (2**14)) // 2)
  end
  if predicate = "unsupported" then return 0

  parse var predicate key "=" value
  if value = "" then return 0
  select
    when key = "pc" then return p["pc"] = octToDec(value)
    when key = "mnemonic" then return p["mnemonic"] = value
    when key = "io.device" then return p["deviceName"] = value | p["xctDeviceName"] = value
    when key = "io.function" then return ioName(p["ioFunction"]) = value | ioName(p["xctIoFunction"]) = value
    otherwise return 0
  end

printPreview: procedure
  use arg p
  say "proposal PC=" || .LROct~fromDecimal(p["pc"])~right -
      .LROct~fromDecimal(p["instruction"])~string p["mnemonic"] -
      "fetch=" || p["fetchSource"]
  if p["format"] = "IO" then
    say "         IO" p["deviceName"] ioName(p["ioFunction"]) -
        "E=" || ifNilOct(p["effectiveAddress"])
  if p["xctInstruction"] \= .nil then do
    say "         XCT->" .LROct~fromDecimal(p["xctInstruction"])~string p["xctMnemonic"]
    if p["xctDevice"] \= .nil then
      say "               IO" p["xctDeviceName"] ioName(p["xctIoFunction"])
  end
  return

printTrace: procedure
  use arg tr,cpu
  say "executed" .LROct~fromDecimal(tr["pcBefore"])~right tr["mnemonic"] -
      "->" .LROct~fromDecimal(tr["pcAfter"])~right -
      "icount=" || cpu~instructionCount
  return

ioName: procedure
  use arg n
  if n = .nil then return "-"
  names="BLKI DATAI BLKO DATAO CONO CONI CONSZ CONSO"
  return word(names,n+1)

ifNilOct: procedure
  use arg v
  if v = .nil then return "NIL"
  return .LROct~fromDecimal(v)~right

octToDec: procedure
  use arg text
  numeric digits 30
  n=0
  do i=1 to text~length
    ch=text~substr(i,1)
    if pos(ch,"01234567")=0 then return -1
    n=n*8+ch
  end
  return n

usage:
  say "usage: rexx KL10Walk.rex state.kl10state step [n]"
  say "   or: rexx KL10Walk.rex state.kl10state until <predicate> [max]"
  return

::requires "../KL10IPL.cls"
