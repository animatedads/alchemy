/* Contract example only. Transport/client construction is deployment-specific. */
req=.HFSpaceJobRequirement~new('GPU',16384,100,.false,.true,.true)
payload=.directory~new
payload['base_model']='google/gemma-2-2b-it'
payload['vocab_target']=65536
payload['recovery_steps']=100
inputs=.array~of(.HFSpaceInputFile~new('input_bundle','corpus_bundle.zip'))
spec=.HFSpaceJobSpec~new('gemma-oorexx-recovery-001',req,payload,inputs,'./outputs',.true,'GEMMA_OOREXX_RECOVERY_V1')
/* result=runner~run(spec) */
say req~canonical
::requires 'HuggingFaceSpaceJob.cls'
