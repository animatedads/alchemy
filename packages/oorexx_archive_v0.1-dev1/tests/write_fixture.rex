parse arg outPath
if outPath == '' then exit 2
w = .Archive~zipWriter
w~addBytes('alpha.txt', copies('alpha-', 200), 8)
w~addBytes('nested/', '', 0)
w~addBytes('nested/beta.bin', x2c('00010203FF') || copies('BETA', 100), 0)
w~writeFile(outPath)
exit 0
::requires '../src/Archive.cls'
