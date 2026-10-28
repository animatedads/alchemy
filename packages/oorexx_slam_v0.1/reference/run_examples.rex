/* run_examples.rex - run each example of a SLAM fact file and write what it printed into its result block.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 *
 *   rexx reference/run_examples.rex FILE.md [FILE.md ...]
 *
 * An example is the three parts FORMAT.md gives: 'the code:' + code block, 'the result:' + code block,
 * and (if the reference gives one) 'the reference says:' + code block. For each example:
 *   - the code is written to a file and run with this interpreter (rexx on PATH), in a new empty folder
 *     for each example, with no input, for at most 10 seconds, in a small environment (env -i: PATH holds
 *     only the folder of rexx, /usr/bin and /bin; HOME is the work folder), so no example sees files an
 *     earlier example wrote, and no output shows the PATH of the computer that ran it;
 *   - the result block becomes exactly what the code printed (standard output, line by line);
 *     if the run ended in an error, the result block holds the error number only, e.g. 40.13;
 *     if the run did not end in 10 seconds, the result block says: not run: it did not end in ten seconds
 *   - a run is SAME when the result block equals the reference block, DIFFERENT when it does not, and
 *     NO REFERENCE when there is no reference block.
 * The file is written again in place. One line per example goes to a report file next to it
 * (FILE.results.txt): file, line of 'the code:', SAME / DIFFERENT / NO REFERENCE, subject-free code summary.
 */
signal on syntax name onSyntax
parse arg files
if files~words == 0 then do
  say 'usage: rexx reference/run_examples.rex FILE.md [FILE.md ...]'
  exit 2
end
work = value('TMPDIR', , 'ENVIRONMENT')
if work == '' then work = '/tmp'
work = work || '/slam_examples_' || date('S') || time('S')
address system 'mkdir -p' work
address system 'command -v rexx' with output stem w.
if w.0 == 0 then do
  say 'rexx is not on PATH'
  exit 2
end
rexxExe = w.1~strip
rexxDir = rexxExe~left(rexxExe~lastPos('/') - 1)
lib = value('LD_LIBRARY_PATH', , 'ENVIRONMENT')
.local~slam.run = 'env -i PATH=' || rexxDir || ':/usr/bin:/bin LD_LIBRARY_PATH=' || lib || ' HOME=' || work || '/run'
totals = .directory~new
do k over .array~of('SAME', 'DIFFERENT', 'NO REFERENCE', 'ERROR', 'TIMEOUT')
  totals[k] = 0
end
do f = 1 to files~words
  call runFile files~word(f), work, totals
end
say 'all files:' 'same' totals['SAME'] ' different' totals['DIFFERENT'] ' no reference' totals['NO REFERENCE'] ' (syntax errors' totals['ERROR'] ' timeouts' totals['TIMEOUT'] || ')'
address system 'rm -rf' work
exit 0

runFile: procedure
  use arg file, work, totals
  lines = .array~new
  do while lines(file) > 0
    lines~append(linein(file))
  end
  call stream file, 'C', 'CLOSE'
  out = .array~new
  report = .array~new
  same = 0; diff = 0; noref = 0
  i = 1
  do while i <= lines~items
    s = lines[i]~strip
    if s \== 'the code:' then do
      out~append(lines[i])
      i += 1
      iterate
    end
    codeLine = i
    code = blockAt(lines, i + 1)          /* .array: [1] lines of the block, [2] index of the closing fence */
    if code == .nil then do
      out~append(lines[i])
      i += 1
      iterate
    end
    j = code[2] + 1
    do while j <= lines~items
      if lines[j]~strip \== '' then leave
      j += 1
    end
    if j > lines~items then do
      out~append(lines[i])
      i += 1
      iterate
    end
    if lines[j]~strip \== 'the result:' then do
      out~append(lines[i])
      i += 1
      iterate
    end
    resultBlock = blockAt(lines, j + 1)
    if resultBlock == .nil then do
      out~append(lines[i])
      i += 1
      iterate
    end
    k = resultBlock[2] + 1
    ref = .nil
    m = k
    do while m <= lines~items
      if lines[m]~strip \== '' then leave
      m += 1
    end
    if m <= lines~items then if lines[m]~strip == 'the reference says:' then ref = blockAt(lines, m + 1)
    printed = runCode(code[1], work, totals)
    /* write the example back: code part unchanged, result block replaced */
    do n = codeLine to code[2]
      out~append(lines[n])
    end
    do n = code[2] + 1 to j
      out~append(lines[n])
    end
    out~append(lines[j + 1])             /* opening fence of the result block */
    do p over printed
      out~append(p)
    end
    out~append(lines[resultBlock[2]])     /* closing fence */
    i = resultBlock[2] + 1
    if ref == .nil then do
      verdict = 'NO REFERENCE'
      noref += 1
    end
    else do
      if sameLines(printed, ref[1]) then do
        verdict = 'SAME'
        same += 1
      end
      else do
        verdict = 'DIFFERENT'
        diff += 1
      end
    end
    totals[verdict] = totals[verdict] + 1
    report~append(file || ':' || codeLine || ' ' || verdict || ' | ' || code[1]~makeString('L', ' / ')~left(100))
  end
  call stream file, 'C', 'OPEN WRITE REPLACE'
  do n = 1 to out~items
    call lineout file, out[n]
  end
  call stream file, 'C', 'CLOSE'
  rep = file || '.results.txt'
  call stream rep, 'C', 'OPEN WRITE REPLACE'
  do r over report
    call lineout rep, r
  end
  call stream rep, 'C', 'CLOSE'
  say file || ': same' same ' different' diff ' no reference' noref
  return

/* The code block that starts at line i (blank lines before it are skipped). */
blockAt: procedure
  use arg lines, i
  do while i <= lines~items
    if lines[i]~strip \== '' then leave
    i += 1
  end
  if i > lines~items then return .nil
  if lines[i]~strip~left(3) \== '```' then return .nil
  body = .array~new
  j = i + 1
  do while j <= lines~items
    if lines[j]~strip~left(3) == '```' then return .array~of(body, j)
    body~append(lines[j])
    j += 1
  end
  return .nil

sameLines: procedure
  use arg a, b
  if a~items \== b~items then return .false
  do n = 1 to a~items
    if a[n] \== b[n] then return .false
  end
  return .true

/* Run the code; give back the lines it printed, or the error number, or the timeout line. */
runCode: procedure
  use arg code, work, totals
  dir = work || '/run'
  prog = dir || '/example.rex'
  outFile = work || '/out.txt'
  errFile = work || '/err.txt'
  address system 'rm -rf' dir outFile errFile '&& mkdir -p' dir
  call stream prog, 'C', 'OPEN WRITE REPLACE'
  do c over code
    call lineout prog, c
  end
  call stream prog, 'C', 'CLOSE'
  address system 'cd' dir '&& timeout 10' .local~slam.run 'rexx' prog '>' outFile '2>' errFile '< /dev/null'
  runRc = rc
  printed = readLines(outFile)
  if runRc == 124 then do
    totals['TIMEOUT'] = totals['TIMEOUT'] + 1
    return .array~of('not run: it did not end in ten seconds')
  end
  errLines = readLines(errFile)
  errNum = ''
  do e over errLines
    parse var e 'Error ' num ':' .
    if num \== '' then if datatype(num~word(1), 'N') then if num~word(1)~pos('.') > 0 then errNum = num~word(1)
  end
  if errNum == '' then do
    do e over errLines
      parse var e 'Error ' num ' running' .
      if num \== '' then if datatype(num, 'W') then do
        errNum = num
        leave
      end
    end
  end
  if errNum \== '' then do
    totals['ERROR'] = totals['ERROR'] + 1
    return .array~of(errNum)              /* FORMAT.md: for an error, the error number only */
  end
  return printed

readLines: procedure
  use arg file
  got = .array~new
  if stream(file, 'C', 'QUERY EXISTS') == '' then return got
  do while lines(file) > 0
    got~append(linein(file))
  end
  call stream file, 'C', 'CLOSE'
  return got

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D')
  exit 1
