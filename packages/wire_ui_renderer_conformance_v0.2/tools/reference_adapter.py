#!/usr/bin/env python3
"""Reference adapter for fixture mechanics only. It is not renderer evidence."""
import json, sys
from pathlib import Path

def main(argv):
    if len(argv)!=3:
        print(f"usage: {argv[0]} CANONICAL_INPUT OUT",file=sys.stderr); return 2
    d=json.loads(Path(argv[1]).read_text())
    definition=d['definition']; key=f"{definition['definitionId']}@{definition['version']}"
    rr=d['resourceBinding']['resourceRef']; s=d['snapshot']; p=d['patches'][0]
    ce=d['collectionEvent']; wc_evt=d['workspaceAction']; sa=d['semanticActivation']; plan=d['observationPlan']
    wc=next(i['workspaceContext'] for i in s['instances'] if i['instanceId']==wc_evt['instanceId'])
    out=[
      {'op':'definition.accept','definitionKey':key,'contentAddress':definition['contentAddress']},
      {'op':'resource.require','definitionKey':key,'role':d['resourceBinding']['role'],'resourceId':rr['resourceId'],'version':rr['version'],'contentAddress':rr['contentAddress'],'locale':rr['locale']},
      {'op':'snapshot.commit','viewRef':d['viewRef'],'revision':s['revision']},
    ]
    out += [{'op':'instance.create','instanceId':i['instanceId'],'definitionKey':i['definitionKey']} for i in s['instances']]
    out += [
      {'op':'property.set','viewRef':d['viewRef'],'fromRevision':p['fromRevision'],'toRevision':p['toRevision'],'instanceId':p['instanceId'],'property':p['slot'],'value':p['value']},
      {'op':'collection.range-request','instanceId':d['rangeRequest']['instanceId'],'start':d['rangeRequest']['start'],'count':d['rangeRequest']['count']},
      {'op':'collection.select','instanceId':ce['instanceId'],'identity':ce['stableIdentity']},
      {'op':'action.emit','viewRef':d['viewRef'],'sourceId':ce['instanceId'],'action':ce['semanticAction'],'renderedRevision':p['toRevision'],'detail':{'identity':ce['stableIdentity']}},
      {'op':'action.emit','viewRef':d['viewRef'],'sourceId':wc_evt['instanceId'],'action':wc_evt['semanticAction'],'renderedRevision':p['toRevision'],'detail':{'workspaceContext':wc}},
      {'op':'action.emit','viewRef':d['viewRef'],'sourceId':sa['instanceId'],'action':sa['semanticAction'],'renderedRevision':p['toRevision'],'detail':{}},
      {'op':'observation.subscription','subscriptionId':plan['subscriptionId'],'enabled':plan['enabled']},
      {'op':'observation.emit','subscriptionId':plan['subscriptionId'],'event':'message.opened','subjectIdentity':ce['stableIdentity']},
      {'op':'definition.deauthorised','definitionKey':d['deauthorisation']['definitionKey'],'committedInstanceId':d['deauthorisation']['committedInstanceId'],'actionsBlocked':True},
      {'op':'resync.request','viewRef':d['viewRef'],'reason':'COMMITTED_VIEW_DEAUTHORISED'}]
    Path(argv[2]).write_text(json.dumps(out,indent=2)+'\n'); return 0
if __name__=='__main__': raise SystemExit(main(sys.argv))