ctx=.MathContext~decimal(30)
depth=.Maths~matrix(.array~of(.array~of(1,2),.array~of(3,4)),ctx)
field=.SurveyDepthField~new(depth,'RELATIVE')
raw=.SurveyDerivedEvidence~new('DEPTH_RAW','Depth Probe','0.2','sha256:photo-a','foreign-depth-ref',.nil,'FOREIGN_DERIVED')
promoted=.SurveyDepthEvidence~new('Depth Probe','0.2','sha256:photo-a',field)
record=.SurveyEvidencePromotion~new(raw,promoted,'Maths-backed depth conversion after provider inference')
if record~rawEvidence \== raw then raise syntax 93.900 array('raw lineage lost')
if record~promotedEvidence \== promoted then raise syntax 93.900 array('promoted lineage lost')
if record~authority \== 'PROMOTION_RECORD_ONLY' then raise syntax 93.900 array('promotion incorrectly gained world authority')
if record~mutatesWorld then raise syntax 93.900 array('promotion must not mutate SurveyWorld')
say 'PASS explicit foreign-evidence promotion boundary'
::requires '../rexx/SurveyForeignProviders.cls'
