/* Contract-only example: does not run unless paths and credentials are real. */
req=.ColabJobRequirement~new("GPU","T4",.false,16384,30720,.true,.true)
inputs=.array~of(.ColabInputFile~new("corpus_bundle.zip","corpus_bundle.zip"))
outputs=.array~of(.ColabOutputFile~new("outputs/training-report.json","./training-report.json"), -
                  .ColabOutputFile~new("outputs/model.tar.gz","./model.tar.gz"))
env=.directory~new
env["HF_HOME"]="/content/oorexx-job-gemma-oorexx-recovery/hf-cache"
deps=.array~of("torch","transformers","datasets","accelerate")
/* Secret values never belong in env. This reference is resolved by Secret Broker
 * only when a runner is constructed with an authorised broker. */
secretBindings=.array~of(.ColabSecretBinding~new("HF_TOKEN","huggingface.primary"))
spec=.ColabJobSpec~new("gemma-oorexx-recovery",req,"train_gemma_oorexx.py", -
  .array~of("--input","corpus_bundle.zip","--base","google/gemma-2-2b-it","--vocab-target","65536","--recovery-steps","100","--output","outputs"), -
  env,deps,inputs,outputs,7200,.false,secretBindings)
say "job="spec~jobId
say "requirements="req~canonical
say "Default behavior is teardown. Construct ColabJobRunner with a SecretBroker before running this HF_TOKEN-bound spec."
::requires "../src/ColabJob.cls"
