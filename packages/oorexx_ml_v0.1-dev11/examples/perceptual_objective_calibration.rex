objective=.MLObjective~new('audio-distance','MINIMIZE','weighted recovered-reference distance + artefact penalties','experimental until calibrated')
config=.directory~new; candidates=.directory~new
candidates['A']=.MLSearchCandidate~new('A','C',config,1.20,objective)
candidates['B']=.MLSearchCandidate~new('B','C',config,1.45,objective)
candidates['C']=.MLSearchCandidate~new('C','C',config,1.05,objective)
s=.MLObjectiveCalibrationSession~new('LISTENING-ROUND-1',objective)
s~addJudgement(.MLPreferenceJudgement~new('P1','reviewer-A','A','B','LEFT',.9,'A clearer','listen:AB'))
s~addJudgement(.MLPreferenceJudgement~new('P2','reviewer-A','C','A','LEFT',.8,'C clearer','listen:CA'))
s~addJudgement(.MLPreferenceJudgement~new('P3','reviewer-B','A','B','RIGHT',.6,'B less harsh','listen:AB2'))
r=s~report(candidates,'AUDIO-V1')
say r~canonicalText
q=.MLObjectiveCalibrationQualification~assess(r,.60,3)
say q~canonicalText
::requires "OorexxML.cls"
