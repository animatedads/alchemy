#!/usr/bin/env rexx
c=.MediaMethodologyCatalogue~new
.MediaMethodologyBuiltins~populate(c)
call assertEq 180,c~count,'catalogue count'
ids=.array~of('AUDIO.SPECTRAL_INTEGRITY.COMPLEMENTARY_BUCKET_VIEWS','AUDIO.SPECTRAL_INTEGRITY.PHASE_SWEEP','AUDIO.SPECTRAL_INTEGRITY.BOUNDED_PREFERENCE_VIEW','AUDIO.SPECTRAL_INTEGRITY.HARMONIC_OBSERVATION','QUAL.AUDIO.SPECTRAL_INTERLEAVE_POSITIVE_CONTROL')
do id over ids
  call assertTrue c~methodology(id)<>.nil,'method present' id
end
call assertTrue c~methodology('AUDIO.SPECTRAL_INTEGRITY.BOUNDED_PREFERENCE_VIEW')~reconstructive,'preference remains reconstruction candidate'
call assertTrue \c~methodology('AUDIO.SPECTRAL_INTEGRITY.COMPLEMENTARY_BUCKET_VIEWS')~reconstructive,'complementary view is measurement'
shapes=.MediaWorkShapeCatalogue~new
.MediaWorkShapeBuiltins~populate(shapes,c)
call assertEq 180,shapes~count,'shape count'
call assertEq 'DERIVED_VIEW_SET',shapes~shape('AUDIO.SPECTRAL_INTEGRITY.COMPLEMENTARY_BUCKET_VIEWS')~mergeMode,'view merge mode'
call assertEq 'QUALIFICATION_REPORT_SET',shapes~shape('QUAL.AUDIO.SPECTRAL_INTERLEAVE_POSITIVE_CONTROL')~mergeMode,'control merge mode'
say 'PASS spectral-integrity methodologies and work shapes'
exit 0
assertTrue: procedure
  use arg value,label
  if value then return
  say 'FAIL' label
  exit 1
assertEq: procedure
  use arg expected,actual,label
  if expected==actual then return
  say 'FAIL' label 'expected='expected 'actual='actual
  exit 1
::requires 'MediaMethodologies.cls'
::requires 'MediaMethodologyBuiltins.cls'
::requires 'MediaMethodologyExecution.cls'
::requires 'MediaWorkShapeBuiltins.cls'
