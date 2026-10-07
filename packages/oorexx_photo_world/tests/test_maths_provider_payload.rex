ctx=.MathContext~decimal(30)
rows=.array~new
rows~append(.array~of(1,2,3))
rows~append(.array~of(4,5,6))
depth=.Maths~matrix(rows,ctx)
field=.SurveyDepthField~new(depth,'RELATIVE')
call expectInvalidDepthKind depth
call expectMetricUnits depth
if field~rows<>2 | field~cols<>3 then raise syntax 93.900 array('depth shape lost')
if field~matrix \== depth then raise syntax 93.900 array('MathMatrix identity lost')
ev=.SurveyDepthEvidence~new('Depth Probe','0.1','sha256:test',field)
if ev~kind<>'DEPTH' then raise syntax 93.900 array('wrong depth evidence kind')
if ev~payload~matrix \== depth then raise syntax 93.900 array('Maths authority not retained')

p=.SurveyMathPayload~new
p~put('DEPTH',depth)
if p~at('depth') \== depth then raise syntax 93.900 array('named Maths payload lost')

verts=.Maths~matrix(.array~of(.array~of(0,0,0),.array~of(1,0,0),.array~of(0,1,0)),ctx)
faces=.Maths~matrix(.array~of(.array~of(1,2,3)),.MathContext~rational)
mesh=.SurveyMeshCandidate~new(verts,faces)
me=.SurveyMeshEvidence~new('Mesh Probe','0.1','sha256:mesh',mesh)
if me~payload~vertices \== verts then raise syntax 93.900 array('mesh Maths vertices lost')
if me~payload~faces \== faces then raise syntax 93.900 array('mesh Maths faces lost')
say 'PASS Maths-owned provider payloads'
exit 0

expectInvalidDepthKind: procedure
  use strict arg depth
  signal on syntax name caughtInvalidDepthKind
  ignored=.SurveyDepthField~new(depth,'UNKNOWN')
  raise syntax 93.900 array('invalid depth kind did not fail closed')
caughtInvalidDepthKind:
  say 'EXPECTED SYNTAX rc='rc 'sigl='sigl 'condition='condition("C") 'description='condition("D")
  return

expectMetricUnits: procedure
  use strict arg depth
  signal on syntax name caughtMetricUnits
  ignored=.SurveyDepthField~new(depth,'METRIC','')
  raise syntax 93.900 array('metric depth without units did not fail closed')
caughtMetricUnits:
  say 'EXPECTED SYNTAX rc='rc 'sigl='sigl 'condition='condition("C") 'description='condition("D")
  return

::requires '../rexx/SurveyForeignProviders.cls'
