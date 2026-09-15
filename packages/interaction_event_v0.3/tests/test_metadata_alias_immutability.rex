contentMeta=.table~new; contentMeta['ROLE']='ORIGINAL'
anchorMeta=.table~new; anchorMeta['SOURCE']='ORIGINAL'
e=.InteractionEvent~new('metadata-alias-1','AGENT_UTTERANCE')
ce=.InteractionContentElement~new('c1','UTTERANCE_SEGMENT','hello','PUBLIC','','RETAIN','AGENT','','',100,contentMeta)
ea=.InteractionEvidenceAnchor~new('src-1','PROVIDER_OUTPUT','PROVIDER:1',.nil,100,anchorMeta)
call assertTrue e~addContent(ce),'content attaches'
call assertTrue e~addEvidence(ea),'anchor attaches'
e~seal
before=e~canonicalText
contentMeta['ROLE']='MUTATED'; contentMeta['LATE']='ADDED'
anchorMeta['SOURCE']='MUTATED'; anchorMeta['LATE']='ADDED'
after=e~canonicalText
call assertEqual before,after,'caller metadata aliases cannot mutate sealed event evidence'
call assertEqual 'ORIGINAL',e~content[1]~metadata['ROLE'],'content owns metadata copy'
call assertEqual 'ORIGINAL',e~evidence[1]~metadata['SOURCE'],'evidence anchor owns metadata copy'
say 'PASS test_metadata_alias_immutability'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'InteractionEvent.cls'
