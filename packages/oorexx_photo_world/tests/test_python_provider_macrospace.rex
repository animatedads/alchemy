/* Requires Python Macrospace v0.31.6 or later.  The five-argument calls are
 * intentional regressions for the @ARGS: arbitrary-arity transport. */
cls = .AlchemyPythonClass~loadCls('photo_world_provider_probe', 'PhotoWorldProviderProbe')
foreign = cls~new('PhotoWorld Probe', '0.2', 'depth', 'x:y', 'semi;colon')
if foreign~providerVersion \== '0.2' then raise syntax 93.900 array ('provider version dispatch failed')
if foreign~combine('a',2,'c:d','',5) \== 'a|2|c:d||5' then raise syntax 93.900 array ('instance arbitrary-arity framing failed')
if cls~class_combine('p',7,'q:r','',9) \== 'p|7|q:r||9' then raise syntax 93.900 array ('class arbitrary-arity framing failed')
provider = .SurveyPythonDepthProvider~new(foreign, 'PhotoWorld Probe')
e1 = provider~infer('photo-a.jpg', 'sha256:a')
e2 = provider~infer('photo-b.jpg', 'sha256:b')
if e1~kind \== 'DEPTH_RAW' then raise syntax 93.900 array ('wrong raw evidence kind')
if e1~sourceDigest \== 'sha256:a' then raise syntax 93.900 array ('source digest lost')
if e1~payload \== 'DEPTH-PROBE:1:photo-a.jpg' then raise syntax 93.900 array ('first dispatch failed')
if e2~payload \== 'DEPTH-PROBE:2:photo-b.jpg' then raise syntax 93.900 array ('resident identity lost')
if foreign~callCount \== '2' then raise syntax 93.900 array ('Python state not retained')
ctx=.MathContext~decimal(30)
mathMatrix=.Maths~matrix(.array~of(.array~of(1,2,3),.array~of(4,5,6)),ctx)
contract=foreign~maths_matrix_contract(mathMatrix)
if contract \== '2x3:2:PURE' then raise syntax 93.900 array ('Maths live-object crossing failed',contract)
say 'PASS Macrospace v0.31.6 arbitrary-arity resident provider + live Maths object crossing'
return 'PHOTO-WORLD-MACROSPACE-V0.31.6-PASS'
::requires '../rexx/SurveyForeignProviders.cls'
::requires 'animals.cls'
