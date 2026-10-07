call rxfuncadd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
say 'XCover camera catalogue:'
do c over .XCoverCameraSpecifications~all
  say c~id c~release c~model
  do lid over c~lensIds
    l=c~lens(lid)
    say '  ' lid 'MP='l~megapixels 'FOV='l~fovMin'-'l~fovMax l~fovAxis 'estimated='l~estimated
  end
end
c=.XCoverCameraSpecifications~byId('XCOVER7')
l=c~mainLens
if l~fovMin<>79 | l~fovMax<>81 then exit 10
if .XCoverCameraSpecifications~all~items<>10 then exit 11
say 'PASS camera catalogue'
::requires '../rexx/CameraSpecifications.cls'
