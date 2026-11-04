call RxFuncAdd 'SysLoadFuncs', 'rexxutil', 'SysLoadFuncs'
call SysLoadFuncs
call SysFileTree '../src/*.cls', 'files.', 'FO'
adapter = .SemanticSourceOorexxStructuralAdapter~new
count = 0
do i = 1 to files.0
  file = files.i
  size = stream(file, 'c', 'query size')
  source = charin(file, 1, size)
  call stream file, 'c', 'close'
  graph = adapter~parse(source, file, 'SSC')
  if graph~reconstruct \== source then do
    say 'FAIL roundtrip:' file
    exit 1
  end
  if graph~objects~items = 0 & source \= '' then do
    say 'FAIL no semantic objects:' file
    exit 1
  end
  count += 1
end
say 'OOREXX STRUCTURAL TREE TEST: PASS files='count
exit 0
::requires '../src/SemanticSourceOorexxStructuralAdapter.cls'
