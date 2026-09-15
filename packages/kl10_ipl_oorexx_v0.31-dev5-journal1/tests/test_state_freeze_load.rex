/* Architectural freeze/load determinism acceptance. */
numeric digits 30
statePath = "/tmp/kl10_state_freeze_load.state"
pc = octToDec("000100")
mem = .KL10Memory~new
ignored = mem~mapZeroPage(0, 0)
do i = 0 to 7
  mem~put(pc + i, makeInstruction(octToDec("201"), (i // 4) + 1, 0, 0, octToDec("001000") + i))
end

cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulatorInBlock(6, 3, octToDec("123456,,654321"))
/* Give APR/PAG non-default but representable architectural state. */
ignored = cpu~apr~cono(3, cpu~ioBus)
pagState = cpu~pag~state
pagState["statusWord"] = octToDec("000047")
pagState["ebPtr"] = octToDec("047000")
pagState["ubPtr"] = octToDec("765000")
pagState["currentAcBlock"] = 0
pagState["previousAcBlock"] = 6
pagState["previousContextSection"] = 0
ignored = cpu~pag~restoreState(pagState)

do 3
  tr = cpu~step
end
checkpointPc = cpu~pc
checkpointAc1 = cpu~accumulator(1)
checkpointAc2 = cpu~accumulator(2)

writer = .KL10State~new
ignored = writer~save(cpu, statePath)
savedMemoryDigest = writer~memoryDigest
savedApr = cpu~apr~state
savedPag = cpu~pag~state
savedIcount = cpu~instructionCount

/* Continue the original universe. */
traceA = ""
do 3
  tr = cpu~step
  traceA = traceA || tr["pcBefore"] || ":" || tr["instruction"] || ":" || tr["pcAfter"] || ";"
end

/* Reconstitute a fresh machine from the architectural file only. */
reader = .KL10State~new
restored = reader~load(statePath)
call assertEq reader~memoryDigest, savedMemoryDigest, "restored memory digest"
call assertEq restored~instructionCount, savedIcount, "restored instruction count"
call assertEq restored~processorMode, "EXEC", "restored processor mode"
call assertEq restored~ioBus~attached, 3, "restored bus attachment count"
call assertEq restored~apr~stateSchema, "KL10_APR_STATE/1", "restored APR schema"
call assertEq restored~pag~stateSchema, "KL10_PAG_STATE/1", "restored PAG schema"
call assertDirectoryEq restored~apr~state, savedApr, "APR state"
call assertDirectoryEq restored~pag~state, savedPag, "PAG state"
call assertEq restored~pc, checkpointPc, "restored PC"
call assertEq restored~accumulator(1), checkpointAc1, "restored AC1"
call assertEq restored~accumulator(2), checkpointAc2, "restored AC2"
call assertEq restored~accumulatorInBlock(6, 3), octToDec("123456,,654321"), "restored alternate AC block"
call assertEq restored~pag~ebPtr, octToDec("047000"), "restored PAG EBR"
call assertEq restored~pag~ubPtr, octToDec("765000"), "restored PAG UBR"
call assertEq restored~pag~previousAcBlock, 6, "restored previous AC block"

traceB = ""
do 3
  tr = restored~step
  traceB = traceB || tr["pcBefore"] || ":" || tr["instruction"] || ":" || tr["pcAfter"] || ";"
end
call assertEq traceB, traceA, "post-restore trace equivalence"
call assertEq restored~pc, cpu~pc, "post-restore PC equivalence"
do ac = 0 to 15
  call assertEq restored~accumulator(ac), cpu~accumulator(ac), "post-restore AC" ac
end

call sysFileDelete statePath
say "PASS test_state_freeze_load"
exit 0

makeInstruction: procedure
  use arg opcode, ac, indirect, index, address
  numeric digits 30
  return opcode * (2 ** 27) + ac * (2 ** 23) + indirect * (2 ** 22) + index * (2 ** 18) + address

octToDec: procedure
  use arg text
  numeric digits 30
  text = changestr(",", text, "")
  n = 0
  do i = 1 to text~length
    n = n * 8 + text~substr(i, 1)
  end
  return n

assertDirectoryEq: procedure
  use arg actual, expected, label
  if actual~items \= expected~items then do
    say "FAIL" label "item count expected=" expected~items "actual=" actual~items
    exit 1
  end
  do key over expected
    if \actual~hasIndex(key) then do
      say "FAIL" label "missing key" key
      exit 1
    end
    if actual[key] \= expected[key] then do
      say "FAIL" label key "expected=" expected[key] "actual=" actual[key]
      exit 1
    end
  end
  return

assertEq: procedure
  use arg actual, expected, label
  if actual \= expected then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::requires "../KL10IPL.cls"
