call rxfuncadd 'sysloadfuncs','rexxutil','sysloadfuncs'
call sysloadfuncs
say 'compile smoke'
::requires '../src/RichSourceCore.cls'
::requires '../src/XmlNativeSource.cls'
::requires '../src/XmlRelationAdapter.cls'
::requires '../src/EdiFactNativeSource.cls'
::requires '../src/EdiFactRelationAdapter.cls'

::requires '../src/GitNativeSource.cls'
::requires '../src/BitcoinCorePublicCorpus.cls'
::requires '../src/CodeEvidenceRules.cls'
::requires '../src/SourceEvidenceRelationAdapter.cls'