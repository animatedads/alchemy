numeric digits 50
versionFile = '../VERSION'
packageVersion = linein(versionFile)
call stream versionFile, 'c', 'close'
if packageVersion = '' then do
  say 'FAIL test_package_version empty VERSION file'
  exit 1
end
if .Units~version \= packageVersion then do
  say 'FAIL test_package_version runtime=' .Units~version 'file=' packageVersion
  exit 1
end
say 'PASS test_package_version' packageVersion
exit 0
::requires '../rexx/Units.cls'
