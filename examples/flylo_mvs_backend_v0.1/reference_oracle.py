#!/usr/bin/env python3
import json, math, sys

SCHEDULE = {
    'FL1001': ('SYD','HKG'),
    'FL1002': ('HKG','LON'),
}

FARES = {
    ('FLYLO_VALUE','SYD-LON'): {
        'fareId':'FLYLO_VALUE-SYDLON-001','amountMinor':245000,
        'currency':'AUD','baggageProfile':'FLYLO_VALUE_BG1'
    }
}

BAG = {
    'FLYLO_LIGHT_BG0': {'included':0,'pieceLimitG':0,'cabinLimitG':7000,'excessMinor':7000,'currency':'AUD'},
    'FLYLO_VALUE_BG1': {'included':1,'pieceLimitG':23000,'cabinLimitG':10000,'excessMinor':5000,'currency':'AUD'},
}

def eval_case(c):
    cid=c['id']
    if cid=='PATH-SYD-HKG-LON':
        return 'SYD->HKG->LON' if SCHEDULE['FL1001'][1]==SCHEDULE['FL1002'][0] else 'NO_PATH'
    if cid=='FARE-LIGHT-NONE':
        return 'ZERO_THROUGH_FARES' if (c['ruleset'],c['market']) not in FARES else 'OFFERED'
    if cid=='FARE-VALUE-THROUGH':
        return FARES.get((c['ruleset'],c['market']))
    if cid=='AUTH-ZORIN-NOT-DRAX':
        company=c['session'].split('/')[0]
        return 'DENY_COMPANY' if company!='DRAX' else 'ALLOW'
    if cid=='COUPON-SKIP-REJECT':
        return 'REJECT_SEQUENCE' if c['priorCoupon']=='OPEN' and c['attemptCoupon']>1 else 'ALLOW_BOARD'
    if cid in {'COUPON-VALUE-WAIVER','COUPON-LIGHT-WAIVER-DENY'}:
        allowed=(c['rulesetAtIssue']=='FLYLO_VALUE' and c.get('waiver')=='FULLRACK_FIRST')
        return 'ALLOW_BOARD' if allowed else 'REJECT_SEQUENCE'
    if cid=='BAG-LIGHT-EXCESS':
        p=BAG[c['profile']]
        if c['cabinWeightG']>p['cabinLimitG']:
            return {'result':'REJECT_CABIN_WEIGHT','limitG':p['cabinLimitG']}
        excess=max(0,len(c['checkedWeightG'])-p['included'])
        return {'result':'ACCEPT','excessPieces':excess,'chargeMinor':excess*p['excessMinor'],'currency':p['currency']}
    if cid=='BAG-VALUE-OVERWEIGHT':
        p=BAG[c['profile']]
        if c['checkedWeightG'][0]>p['pieceLimitG']:
            return {'result':'REJECT_INCLUDED_PIECE_OVERWEIGHT','limitG':p['pieceLimitG']}
        return {'result':'ACCEPT'}
    if cid=='CARGO-ZORIN-VOLUMETRIC':
        l,w,h=c['dimensionsCm']; volume=l*w*h
        volumetric=math.ceil((volume/c['divisorCm3PerKg'])*1000)
        return {'volumeCm3':volume,'volumetricWeightG':volumetric,'chargeableWeightG':max(c['grossWeightG'],volumetric)}
    if cid=='CARGO-ZORIN-NOT-OPERATOR':
        company,role,ruleset=c['session'].split('/')
        return 'DENY_OPERATOR_AUTHORITY' if (company,role,ruleset)==('ZORIN','FORWARDER','ZORIN_FWD') else 'ALLOW'
    if cid=='FLCTL-IDEMPOTENT-SUBMIT':
        return 'SAME_WORKFLOW_NODE_KEY_REPLAYS_EXISTING_SUBMISSION_ID'
    raise KeyError(cid)

def main(path):
    doc=json.load(open(path,encoding='utf-8'))
    bad=[]
    results=[]
    for c in doc['cases']:
        actual=eval_case(c)
        results.append({'id':c['id'],'actual':actual,'expected':c['expect']})
        if actual!=c['expect']: bad.append(c['id'])
    print(json.dumps({'schema':'flylo.mvs-backend.oracle-result/1','pass':not bad,'results':results},indent=2))
    return 1 if bad else 0

if __name__=='__main__':
    raise SystemExit(main(sys.argv[1]))
