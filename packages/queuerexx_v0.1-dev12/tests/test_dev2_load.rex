say .QueueRexxVersion~version
say .QueueState~name(.QueueState~RUNNING)
say .QueueJobObservation~label(.QueueJobObservation~LIVE)
say .QueueSchema~HEALTH
exit 0
::requires "../src/QueueRexxHealth.cls"
::requires "../src/QueueRexxSerialization.cls"
::requires "../src/QueueRexxEvents.cls"
