/* run_plan42.rex
   Plan 42 spec runner.

   Loads a spec JSON, generates code for the requested target language,
   writes it to a temp file, and executes it.

   Usage:
     rexx run_plan42.rex <spec.json> --target <lang> [options]

   Options:
     --target  <lang>        python3 | oorexx | bash   (required)
     --main    <routine>     name of entry-point routine (default: main)
     --arg     <key>=<val>   argument passed to generated program (repeatable)
     --output  <file>        write generated code here and keep it
     --keep                  keep generated temp file after execution
     --dry-run               generate but do not execute
     --quiet                 suppress run_plan42 banner

   Examples:
     rexx run_plan42.rex tools/wik_lang_scope.spec.json \
         --target python3 \
         --arg input_path=/srv/space/wik/raw-wiktextract-data.jsonl \
         --arg output_dir=data/wordnet/lang \
         --arg progress_interval=500000

     rexx run_plan42.rex tools/wik_lang_scope.spec.json \
         --target oorexx --dry-run --output generated/wik_lang_scope.rex
*/

parse arg _cmdLine

/* -- 1. Parse command line -------------------------------------------- */
specFile   = ''
targetLang = ''
mainName   = 'main'
outFile    = ''
keepFile   = .false
dryRun     = .false
quiet      = .false
argPairs   = .Array~new   /* Array of 'key=value' strings */

_rest = strip(_cmdLine)
do while _rest \= ''
  parse var _rest _token _rest
  _token = strip(_token)
  if _token = '' then iterate

  select
    when _token = '--target' then do
      parse var _rest targetLang _rest
      targetLang = translate(strip(targetLang))
    end
    when _token = '--main' then do
      parse var _rest mainName _rest
      mainName = strip(mainName)
    end
    when _token = '--arg' then do
      parse var _rest _pair _rest
      argPairs~append(strip(_pair))
    end
    when _token = '--output' then do
      parse var _rest outFile _rest
      outFile = strip(outFile)
    end
    when _token = '--keep'     then keepFile = .true
    when _token = '--dry-run'  then dryRun   = .true
    when _token = '--quiet'    then quiet    = .true
    otherwise
      /* First non-flag token is the spec file */
      if specFile = '' then specFile = _token
  end
end

if \quiet then
  say '[plan42] run_plan42.rex  spec='||specFile||'  target='||targetLang

/* -- Validate -------------------------------------------------------- */
if specFile = '' then do
  say 'Usage: rexx run_plan42.rex <spec.json> --target <lang> [--arg key=val ...]'
  exit 1
end
if targetLang = '' then do
  say 'Error: --target is required (python3 | oorexx | bash)'
  exit 1
end
if stream(specFile, 'c', 'query exists') = '' then do
  say 'Error: spec file not found:' specFile
  exit 1
end

/* -- 2. Load spec ----------------------------------------------------- */
signal on syntax name LoadFailed
ps = .ProgramSpec~new(.nil)
loadOk = ps~loadFile(specFile)
signal off syntax
if \loadOk then do
  say 'Error: spec file failed to parse:' specFile
  say '  Check JSON:  python3 -c "import json; json.load(open(chr(39)||specFile||chr(39)))"'
  exit 1
end

moduleName = ps~moduleName
if \quiet then say '[plan42] module:' moduleName


/* -- 2b. Delegate compiler-owned targets to the canonical Python compiler --
   C and Rust are maintained in tools/plan42c.py on this line.  The ooRexx
   generator path may know about these targets, but it does not yet emit the
   same embedded Plan42 markers / wrapper structure.  Route them through the
   canonical compiler so run_plan42.rex and direct tools/plan42c.py stay in
   parity for these targets. */
if _usePythonPlan42c(targetLang) then do
  if outFile = '' then do
    ts = date('S') || 't' || translate(time(), '', ':')
    ext = _extensionFor(targetLang)
    outFile = _tempPath(moduleName, ts, ext)
    isTempFile = .true
  end
  else
    isTempFile = .false

  pyCompiler = _findPythonPlan42c()
  emitCmd = 'python3 "' || pyCompiler || '" "' || specFile || '" --target ' || targetLang || ' -o "' || outFile || '"'
  if \quiet then say '[plan42] delegating' targetLang 'generation to:' emitCmd

  signal on syntax name PythonCompilerFailed
  address system emitCmd
  rc_emit = rc
  signal off syntax
  if rc_emit \= 0 then do
    say 'Error: Python Plan42 compiler failed for target' targetLang 'rc=' || rc_emit
    exit rc_emit
  end

  if \quiet then say '[plan42] wrote:' outFile

  if dryRun then do
    say '[plan42] --dry-run: skipping execution'
    say '[plan42] generated file:' outFile
    exit 0
  end

  genArgs = ''
  do pair over argPairs
    parse var pair pKey '=' pVal
    genArgs = genArgs || ' --' || pKey || ' "' || pVal || '"'
  end
  genArgs = strip(genArgs)

  execCmd = _execCommand(targetLang, outFile, genArgs)
  if execCmd = '' then do
    say 'Warning: no direct execution command for' targetLang '-- generated file kept at' outFile
    exit 0
  end
  if \quiet then say '[plan42] exec:' execCmd

  signal on syntax name ExecFailed
  address system execCmd
  rc_exec = rc
  signal off syntax

  if \quiet then say '[plan42] rc=' || rc_exec

  if isTempFile & \keepFile then do
    call SysFileDelete outFile
    if \quiet then say '[plan42] cleaned:' outFile
  end

  exit rc_exec
end

/* -- 3. Find the main routine and its params ------------------------ */
mainParams = ps~routineParams(mainName)
if mainParams = .nil then do
  say 'Warning: routine "'||mainName||'" not found in spec -- entry point may be empty'
  mainParams = .Array~new
end

/* -- 4. Get the right generator -------------------------------------- */
signal on syntax name GeneratorFailed
gen = .GeneratorFactory~forLanguage(targetLang, .nil)
signal off syntax
if gen = .nil then do
  say 'Error: no generator for target language:' targetLang
  exit 1
end
/* Load preferred capabilities so impls get inlined not stubbed       */
_prefPath = 'preferred/preferred.capabilities.json'
if stream(_prefPath,'c','query exists') \= '' then
  gen~loadPreferred(_prefPath)
else
  say '[plan42] preferred: not found at' _prefPath '-- impls will be stubs'

/* -- 5. Generate code ------------------------------------------------- */
if \quiet then say '[plan42] generating for target:' targetLang
signal on syntax name GenerateFailed
code = gen~generate(ps)
if \quiet then say '[plan42] emitting entry point for:' mainName
entryPoint = gen~emitEntryPoint(mainName, mainParams)
fullCode = code || entryPoint
signal off syntax

if \quiet then say '[plan42] generated:' length(fullCode) 'chars'

/* -- Preview first 5 lines of generated code ------------------------ */
if \quiet then do
  say '[plan42] --- generated preview ---'
  previewLines = fullCode~makeArray('0a'x)
  do pi = 1 to min(5, previewLines~items)
    say '[plan42]' pi':' previewLines~at(pi)
  end
  say '[plan42] ---'
end

/* -- 6. Determine output file ----------------------------------------- */
if outFile = '' then do
  /* Temp file: module name + timestamp + target extension */
  ts = date('S') || 't' || translate(time(), '', ':')
  ext = _extensionFor(targetLang)
  outFile = _tempPath(moduleName, ts, ext)
  isTempFile = .true
end
else
  isTempFile = .false

/* -- 7. Write generated code ------------------------------------------ */
signal on syntax   name WriteFailed
signal on notready name WriteFailed
sf = .Stream~new(outFile)
call SysFileDelete outFile
sf~open('write replace')
sf~charout(fullCode)
sf~close
signal off syntax
signal off notready

if \quiet then say '[plan42] wrote:' outFile

/* -- 8. Execute (unless --dry-run) ------------------------------------  */
if dryRun then do
  say '[plan42] --dry-run: skipping execution'
  say '[plan42] generated file:' outFile
  exit 0
end

/* Build argument string for generated program */
genArgs = ''
do pair over argPairs
  parse var pair pKey '=' pVal
  genArgs = genArgs || ' --' || pKey || ' "' || pVal || '"'
end
genArgs = strip(genArgs)

/* Build the execution command */
execCmd = _execCommand(targetLang, outFile, genArgs)
if \quiet then say '[plan42] exec:' execCmd

signal on syntax name ExecFailed
address system execCmd
rc_exec = rc
signal off syntax

if \quiet then say '[plan42] rc=' || rc_exec

/* -- 9. Cleanup -------------------------------------------------------- */
if isTempFile & \keepFile then do
  call SysFileDelete outFile
  if \quiet then say '[plan42] cleaned:' outFile
end

exit rc_exec

/* -- Error handlers --------------------------------------------------- */
LoadFailed:
  __condD = condition('D'); __condC = condition('C')
  signal off syntax
  say 'Error loading spec:' specFile
  say '  condition:' __condC '  description:' __condD
  exit 1

GeneratorFailed:
  __condD = condition('D'); __condC = condition('C')
  signal off syntax
  say 'Error creating generator for:' targetLang
  say '  condition:' __condC '  description:' __condD
  exit 1

GenerateFailed:
  __condObj = condition('O')
  __condD = condition('D'); __condC = condition('C')
  __sigl  = sigl
  signal off syntax
  say 'Error generating code from spec:' specFile
  say '  condition:' __condC '  line:' __sigl
  if __condObj \= .nil then do
    say '  message:  ' __condObj~message
    say '  code:     ' __condObj~code
    if __condObj~traceback \= .nil then do
      say '  --- traceback ---'
      do __tbLine over __condObj~traceback
        say '    ' __tbLine
      end
    end
  end
  say '  description:' __condD
  exit 1

PythonCompilerFailed:
  __condD = condition('D'); __condC = condition('C')
  signal off syntax
  say 'Error invoking Python Plan42 compiler'
  say '  condition:' __condC '  description:' __condD
  exit 1

WriteFailed:
  signal off syntax
  signal off notready
  say 'Error writing generated file:' outFile
  exit 1

ExecFailed:
  __condD = condition('D'); __condC = condition('C')
  signal off syntax
  say 'Error executing generated program'
  say '  condition:' __condC '  description:' __condD
  exit 1

/* -- Helpers ----------------------------------------------------------- */
_usePythonPlan42c: procedure
  use arg lang
  lang = translate(strip(lang))
  if lang = 'C' | lang = 'C11' | lang = 'RUST' | lang = 'CPP' | lang = 'C++' | lang = 'JAVA' then return 1
  return 0

_findPythonPlan42c: procedure
  if stream('tools/plan42c.py', 'c', 'query exists') \= '' then return 'tools/plan42c.py'
  if stream('plan42c.py', 'c', 'query exists') \= '' then return 'plan42c.py'
  return 'tools/plan42c.py'

_extensionFor: procedure
  use arg lang
  select
    when lang = 'PYTHON3' | lang = 'PYTHON' then return 'py'
    when lang = 'OOREXX'  | lang = 'REXX'   then return 'rex'
    when lang = 'BASH'                       then return 'sh'
    when lang = 'C' | lang = 'C11'           then return 'c'
    when lang = 'GO'                         then return 'go'
    when lang = 'RUST'                       then return 'rs'
    when lang = 'JAVA'                       then return 'java'
    when lang = 'CPP' | lang = 'C++'         then return 'cpp'
    when lang = 'C' | lang = 'C11'           then return 'c'
    when lang = 'DOTNET'  | lang = 'CS'      then return 'cs'
    otherwise return 'txt'
  end

_execCommand: procedure
  use arg lang, outFile, args
  select
    when lang = 'PYTHON3' | lang = 'PYTHON' then
      return 'python3 "' || outFile || '" ' || args
    when lang = 'OOREXX' | lang = 'REXX' then
      return 'rexx "' || outFile || '" ' || args
    when lang = 'BASH' then
      return 'bash "' || outFile || '" ' || args
    when lang = 'C' | lang = 'C11' then
      return 'cc -std=c11 "' || outFile || '" -o "' || outFile || '.bin" && "' || outFile || '.bin" ' || args
    when lang = 'RUST' then
      return 'rustc "' || outFile || '" -o "' || outFile || '.bin" && "' || outFile || '.bin" ' || args
    when lang = 'GO' then
      return 'go run "' || outFile || '" ' || args
    otherwise
      say 'Warning: no direct execution for' lang '-- compile step required'
      return ''
  end

_tempPath: procedure
  use arg modName, ts, ext
  /* Keep temp files in current dir under a _plan42_tmp/ folder        */
  dir = '_plan42_tmp'
  call SysMkDir dir
  /* Sanitise module name for filesystem */
  safe = ''
  do i = 1 to length(modName)
    ch = substr(modName, i, 1)
    if pos(ch, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-') > 0 then
      safe = safe || ch
    else
      safe = safe || '_'
  end
  return dir || '/' || safe || '_' || ts || '.' || ext

::requires 'spec/ProgramSpec.cls'
::requires 'preferred/PreferredModule.cls'
