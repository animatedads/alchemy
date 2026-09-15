/* PDP-10 halfword family acceptance: opcodes 500..577 octal.
 *
 * Exercises all sixteen halfword functions across the four canonical forms:
 * memory->AC, immediate->AC, AC->memory, and memory modify/store->AC.
 * Read/write counts distinguish preserve-M forms from direct store forms, and
 * the sign-extension groups exercise both positive and negative source halves.
 */
numeric digits 30
pc = octToDec("000100")
y = octToDec("400200")
indexAdd = octToDec("000005")
ea = octToDec("400205")
aValue = octToDec("523456254321")
mValue = octToDec("345612634567")

bases = "HLL HRL HLLZ HRLZ HLLO HRLO HLLE HRLE HRR HLR HRRZ HLRZ HRRO HLRO HRRE HLRE"

do group = 0 to 15
  base = word(bases, group + 1)
  do form = 0 to 3
    opcode = octToDec("500") + group * 4 + form
    select
      when form = 0 then name = base
      when form = 1 then name = base || "I"
      when form = 2 then name = base || "M"
      otherwise name = base || "S"
    end

    mem = .CountingMemory~new
    mem~put(pc, makeInstruction(opcode, 3, 0, 4, y))
    mem~put(ea, mValue)
    mem~resetCounts

    cpu = .KL10CPU~new~~loadImage(mem, pc)
    cpu~setAccumulator(3, aValue)
    cpu~setAccumulator(4, indexAdd)

    tr = cpu~step
    call assertEq tr["mnemonic"], name, name "decode"
    call assertEq tr["effectiveAddress"], ea, name "indexed E"
    call assertEq tr["halfwordGroup"], group, name "group"
    call assertEq tr["halfwordForm"], form, name "form"

    select
      when form = 0 then do
        source = mValue
        destination = aValue
        expectedResult = halfOracle(group, source, destination)
        expectedAc = expectedResult
        expectedMem = mValue
        expectedReads = 2
        expectedWrites = 0
      end
      when form = 1 then do
        source = ea
        destination = aValue
        expectedResult = halfOracle(group, source, destination)
        expectedAc = expectedResult
        expectedMem = mValue
        expectedReads = 1
        expectedWrites = 0
      end
      when form = 2 then do
        source = aValue
        destination = mValue
        expectedResult = halfOracle(group, source, destination)
        expectedAc = aValue
        expectedMem = expectedResult
        mode = (group // 8) % 2
        if mode = 0 then expectedReads = 2
        else expectedReads = 1
        expectedWrites = 1
      end
      otherwise do
        source = mValue
        destination = mValue
        expectedResult = halfOracle(group, source, destination)
        expectedAc = expectedResult
        expectedMem = expectedResult
        expectedReads = 2
        expectedWrites = 1
      end
    end

    call assertEq tr["result"], expectedResult, name "result"
    call assertEq cpu~accumulator(3), expectedAc, name "AC destination"
    readsBeforeVerify = mem~reads
    writesBeforeVerify = mem~writes
    call assertEq mem~word(ea), expectedMem, name "memory state"
    call assertEq readsBeforeVerify, expectedReads, name "read count"
    call assertEq writesBeforeVerify, expectedWrites, name "write count"
    call assertEq cpu~flags, 0, name "FLAGS unchanged"
  end
end

/* Every S form performs its memory modify/store but suppresses the accumulator
 * destination for AC=0. */
do group = 0 to 15
  opcode = octToDec("500") + group * 4 + 3
  mem = .CountingMemory~new
  mem~put(pc, makeInstruction(opcode, 0, 0, 0, ea))
  mem~put(ea, mValue)
  mem~resetCounts
  cpu = .KL10CPU~new~~loadImage(mem, pc)
  cpu~setAccumulator(0, aValue)
  tr = cpu~step
  call assertEq cpu~accumulator(0), aValue, tr["mnemonic"] " AC0 suppression"
  call assertEq mem~writes, 1, tr["mnemonic"] " modify/store write retained"
end

/* HLLM through address 17 octal must combine against the LIVE AC17 right half
 * and write the result back to AC17.  Contradictory backing core under address
 * 17 remains hidden and untouched. */
hidden = octToDec("111111222222")
visible = octToDec("333333444444")
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("502"), 3, 0, 0, octToDec("17")))
mem~put(octToDec("17"), hidden)
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(3, aValue)
cpu~setAccumulator(octToDec("17"), visible)
tr = cpu~step
expectedAlias = halfOracle(0, aValue, visible)
call assertEq cpu~accumulator(octToDec("17")), expectedAlias, "HLLM to address 17 updates live AC17"
call assertEq mem~word(octToDec("17")), hidden, "hidden backing core under AC17 untouched"

say "KL10 halfword family acceptance: PASS"
say "  all 64 opcodes 500..577 exercised with indexed section-zero E"
say "  M forms preserve/zero/ones/sign-extend with correct memory access shape"
say "  all S forms retain memory writes and AC0 suppression"
say "  HLLM through address 000017 combines with and updates live AC17"
exit 0

halfOracle: procedure
  use arg group, source, destination
  numeric digits 30
  h = 2 ** 18
  mask = h - 1
  sign = 2 ** 17
  sl = (source % h) // h
  sr = source // h
  dl = (destination % h) // h
  dr = destination // h
  select
    when group = 0  then do; rl = sl; rr = dr; end  /* HLL  */
    when group = 1  then do; rl = sr; rr = dr; end  /* HRL  */
    when group = 2  then do; rl = sl; rr = 0; end   /* HLLZ */
    when group = 3  then do; rl = sr; rr = 0; end   /* HRLZ */
    when group = 4  then do; rl = sl; rr = mask; end/* HLLO */
    when group = 5  then do; rl = sr; rr = mask; end/* HRLO */
    when group = 6  then do; rl = sl; if sl >= sign then rr = mask; else rr = 0; end /* HLLE */
    when group = 7  then do; rl = sr; if sr >= sign then rr = mask; else rr = 0; end /* HRLE */
    when group = 8  then do; rl = dl; rr = sr; end  /* HRR  */
    when group = 9  then do; rl = dl; rr = sl; end  /* HLR  */
    when group = 10 then do; rl = 0; rr = sr; end   /* HRRZ */
    when group = 11 then do; rl = 0; rr = sl; end   /* HLRZ */
    when group = 12 then do; rl = mask; rr = sr; end/* HRRO */
    when group = 13 then do; rl = mask; rr = sl; end/* HLRO */
    when group = 14 then do; rr = sr; if sr >= sign then rl = mask; else rl = 0; end /* HRRE */
    otherwise do; rr = sl; if sl >= sign then rl = mask; else rl = 0; end             /* HLRE */
  end
  return rl * h + rr

makeInstruction: procedure
  use arg opcode, ac, indirect, x, address
  numeric digits 30
  return opcode * (2 ** 27) + ac * (2 ** 23) + indirect * (2 ** 22) + x * (2 ** 18) + address

octToDec: procedure
  use arg text
  numeric digits 30
  n = 0
  do i = 1 to text~length
    n = n * 8 + text~substr(i, 1)
  end
  return n

assertEq: procedure
  use arg actual, expected, label
  if actual \= expected then do
    say "FAIL:" label
    say "  expected:" expected
    say "  actual:  " actual
    exit 1
  end
  return

::class CountingMemory public
::method init
  expose words readCount writeCount
  words = .directory~new
  readCount = 0
  writeCount = 0
::method put
  expose words writeCount
  use arg address, value
  numeric digits 30
  words[address] = value // (2 ** 36)
  writeCount = writeCount + 1
  return self
::method word
  expose words readCount
  use arg address
  readCount = readCount + 1
  if words~hasIndex(address) then return words[address]
  return 0
::method reads
  expose readCount
  return readCount
::method writes
  expose writeCount
  return writeCount
::method resetCounts
  expose readCount writeCount
  readCount = 0
  writeCount = 0
  return self

::requires "../KL10IPL.cls"
