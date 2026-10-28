/* Read the BIF contracts on both sides, compare them, and write the cases SLAM chooses from them,
 * each with both sides' predictions, before anything runs.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 * Args: interpreter dir (oorexx-5.3.0-.../interpreter) | rxbif.cpp | differential.cpp | cases file to write
 * Cases file lines:  ID|NAME|interp prediction|native prediction|why|argument count|arg1|arg2...
 */
signal on syntax name onSyntax
parse arg interpDir '|' rxbif '|' differential '|' casesOut
ip = .BifInterpreter~new
do f over .array~of('classes/StringClass.cpp', 'classes/StringClassSub.cpp', 'classes/StringClassMisc.cpp', 'classes/StringClassWord.cpp', 'classes/StringClassBit.cpp', 'classes/StringClassConversion.cpp', 'classes/support/StringUtil.cpp')
  ip~addMethods(interpDir || '/' || f)
end
interp = ip~read(interpDir || '/expression/BuiltinFunctions.cpp')
native = .BifNative~new~read(rxbif)
say 'interpreter BIFs read:' interp~items '  native BIFs read:' native~items
both = .array~new
do nm over native~allIndexes~sort
  if interp~hasIndex(nm) then both~append(nm)
end
say 'in both:' both~items
say
say '== contracts (interpreter | native), and where they differ'
differ = 0
do nm over both
  a = interp[nm]; b = native[nm]
  diffs = ''
  if a~min \= b~min | a~max \= b~max then diffs = diffs 'arity'
  mx = max(a~max, b~max)
  do p = 1 to mx
    ka = a~kindAt(p); kb = b~kindAt(p)
    if \same(ka, kb) then diffs = diffs 'arg' || p || '(' || ka || '/' || kb || ')'
  end
  mark = ' '
  if diffs \== '' then do; mark = '*'; differ += 1; end
  say mark left(a~show, 44) '|' left(b~show, 44) diffs
end
say differ 'of' both~items 'BIFs differ somewhere'

/* base arguments: for each BIF, the rx2cpp lane's own differential case with the most arguments */
base = .directory~new
text = charin(differential, 1, chars(differential)); call stream differential, 'C', 'CLOSE'
toks = .SlamCppLexer~new(text)~scan
do i = 1 to toks~items - 3
  if toks[i]~text \== '{' then iterate
  if toks[i + 1]~kind \== 'STRING' then iterate
  if toks[i + 2]~text \== ',' then iterate
  if toks[i + 3]~text \== '{' then iterate
  nm = toks[i + 1]~text~strip('B', '"')
  args = .array~new
  k = i + 4
  do while k <= toks~items
    if toks[k]~text == '}' then leave
    if toks[k]~kind == 'STRING' then args~append(unquote(toks[k]~text))
    k += 1
  end
  if \base~hasIndex(nm) then base[nm] = args
  else if args~items > base[nm]~items then base[nm] = args
end

/* cases: the base; one too few and one too many arguments; each numeric argument at -1, 0 and x;
   each pad argument as two characters */
id = 0
call lineout casesOut, , 1
do nm over both
  if \base~hasIndex(nm) then iterate
  a = interp[nm]; b = native[nm]
  args = base[nm]
  call emit nm, args, 'base (the lane''s own case)'
  if a~min > 0 then do
    short = .array~new
    do p = 1 to a~min - 1; short~append(args[p]); end
    call emit nm, short, 'one argument too few'
  end
  long = .array~new
  do p = 1 to args~items; long~append(args[p]); end
  okFill = .true
  do p = args~items + 1 to a~max + 1
    k = a~kindAt(p)
    select
      when k == 'PAD' then long~append('*')
      when k == '' | k == 'STRING' then long~append('a')
      when k == 'OPTION' then okFill = .false
      otherwise long~append('1')
    end
  end
  if okFill then call emit nm, long, 'one argument too many'
  do p = 1 to args~items
    k = a~kindAt(p) b~kindAt(p)
    if k~pos('INTEGER') > 0 | k~pos('LENGTH') > 0 | k~pos('POSITION') > 0 | k~pos('COUNT') > 0 then do
      do v over .array~of('-1', '0', 'x')
        call emit nm, swap(args, p, v), 'argument' p '=' v
      end
    end
    if k~pos('PAD') > 0 then call emit nm, swap(args, p, 'ab'), 'argument' p '= two characters'
  end
end
call stream casesOut, 'C', 'CLOSE'
say
say id 'cases written, each with both predictions'
exit 0

emit:
  use arg ename, eargs, why
  id += 1
  pa = interp[ename]~predict(eargs)
  pb = native[ename]~predict(eargs)
  if pa == '' then pa = '?'
  if pb == '' then pb = '?'
  call lineout casesOut, id || '|' || ename || '|' || pa || '|' || pb || '|' || why || '|' || eargs~items || '|' || eargs~makeString('L', '|')
  return

swap: procedure
  use arg args, p, v
  out = .array~new
  do k = 1 to args~items; out~append(args[k]); end
  out[p] = v
  return out

/* Are two kinds the same need? COUNT:0 is LENGTH, COUNT:1 is POSITION. */
same: procedure
  use arg a, b
  if a == b then return .true
  if a == 'LENGTH' then if b == 'COUNT:0' then return .true
  if a == 'POSITION' then if b == 'COUNT:1' then return .true
  return .false

unquote: procedure
  use arg s
  s = s~substr(2, s~length - 2)
  s = s~changeStr('\"', '"')~changeStr('\\', '\')
  return s

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')~traceback~makeArray~makeString('L', ' | ')
  exit 1

::requires 'BifContracts.cls'
