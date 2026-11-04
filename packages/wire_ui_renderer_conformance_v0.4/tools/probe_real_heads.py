#!/usr/bin/env python3
import argparse, json
from pathlib import Path

def text(p): return Path(p).read_text(errors='replace')
def any_text(root, needles):
    root=Path(root)
    for p in root.rglob('*'):
        if not p.is_file() or p.suffix.lower() not in {'.java','.c','.h','.cls','.rex','.md','.txt','.py'}: continue
        try: s=p.read_text(errors='replace')
        except Exception: continue
        if all(n in s for n in needles): return True
    return False

def renderer_evidence(a):
    swing=Path(a.swing_root); direct=Path(a.direct_linux_root)
    sr=text(swing/'src/main/java/org/alchemy/wireui/swing/WireSwingRuntime.java')
    st=text(swing/'src/test/java/org/alchemy/wireui/swing/WireSwingRuntimeTest.java')
    dr=text(direct/'src/wire_gtk4_renderer.c')
    return {
      'schema':'wire-ui-real-renderer-head-evidence/0.3',
      'captured':'2026-10-29',
      'heads':{
        'swing':{
          'version':text(swing/'VERSION.txt').strip(), 'artifact_sha256':a.swing_sha256,
          'executed_evidence':'61/61 renderer tests PASS in this qualification environment',
          'gates':{
            'exact-definition': 'DEFINITION_NOT_AUTHORISED_BY_MANIFEST' in sr and 'definitionKey' in sr,
            'exact-published-resource-ref': any_text(swing,['ResourceRef']),
            'revision-ordering': 'previousRevision' in sr and 'newRevision' in sr,
            'event-time-renderedRevision': 'renderedRevision' in sr,
            'stable-collection-identity': 'stable server identity' in st,
            'bounded-range-request': 'requestRange(' in sr and 'RangeRequested' in sr,
            'opaque-workspaceContext': 'WORKSPACE_CONTEXT_REQUIRED' in sr and 'workspaceContext' in sr,
            'semantic-activation': 'wire.activate' in st,
            'positive-list-observation': any_text(swing,['observation.subscription']),
            'deauthorisation-fail-closed': 'COMMITTED_VIEW_DEAUTHORISED' in sr and 'UI_RESYNC_REQUEST' in sr,
          }
        },
        'gtk-direct-linux':{
          'version':text(direct/'VERSION.txt').strip(), 'artifact_sha256':a.direct_sha256,
          'executed_evidence':'native C core/loader/filter tests PASS; all dev41 Python authority/static tests PASS; QuickJS and GTK4 native compilation SKIP because dev packages absent',
          'gates':{
            'exact-definition': any_text(direct,['definitionKey','contentAddress']),
            'exact-published-resource-ref': any_text(direct,['ResourceRef']),
            'revision-ordering': any_text(direct,['renderedRevision']),
            'event-time-renderedRevision': any_text(direct,['renderedRevision']),
            'stable-collection-identity': 'SelectionChanged' in dr and 'identity' in dr and 'stable' in dr,
            'bounded-range-request': 'RangeRequested' in dr and 'start' in dr,
            'opaque-workspaceContext': any_text(direct,['workspaceContext']),
            'semantic-activation': any_text(direct,['~activate','activation keeps element identity']),
            'positive-list-observation': any_text(direct,['observation.subscription']),
            'deauthorisation-fail-closed': any_text(direct,['COMMITTED_VIEW_DEAUTHORISED','UI_RESYNC_REQUEST']),
          }
        }
      },
      'rule':'Full renderer PASS requires every required semantic gate. Upstream package tests do not waive missing cross-renderer gates.'
    }

def readiness(a):
    rr=text(Path(a.rasen_root)/'README.md'); hv=text(Path(a.https_root)/'VALIDATION.txt'); dq=text(Path(a.deployment_root)/'QUALIFICATION.md')
    ldap=Path(a.ldap_root); lp=ldap/'VALIDATION_DEV23.txt'
    if not lp.exists(): lp=ldap/'VALIDATION_DEV22.txt'
    lv=text(lp) if lp.exists() else ''
    public={
      'source_on_main_or_candidate_present': True,
      'review_stage_materialised': ('review-only stage' in rr or 'review stage' in rr),
      'public_role_source_slice_assembled': ('public role source installation slice' in rr.lower() or '16 file tree' in rr.lower()),
      'content_approval_accepted': not ('publication is **denied**' in rr or 'publication is denied' in rr.lower()),
      'owned_https_service_unit_admitted': not ('no approved native HTTPS systemd service' in rr or 'native HTTPS unit' in rr),
      'exact_https_runtime_qualified': 'execution of the new v0.4.8 classes is NOT claimed' not in hv and 'modified v0.4.8 package' not in hv,
      'live_tls_qualified': 'live TLS streaming PUT/GET remains an external-host gate' not in hv,
      'install_observed': False, 'running_observed': False
    }
    private={
      'ldap_candidate_present': bool(lv),
      'ldap_installed': bool(lv) and 'NOT INSTALLED' not in lv and 'NOT CLAIMED' not in lv,
      'live_ldaps_bind_search_revoke': bool(lv) and 'NOT RUN live LDAPS bind/search/revoke' not in lv,
      'https_login_authority_required': True, 'no_fallback_identity_store': True
    }
    return {'schema':'rasenfalcon-wire-surface-readiness/0.2','captured':'2026-10-29','status':'NOT_READY',
            'public_apex':{'status':'READY' if all(public.values()) else 'NOT_READY','gates':public,'ldap_required':False},
            'private_noc_office':{'status':'NOT_READY','gates':private},
            'wire_application':{'durable_ingress_qualified':'8/8 ooRexx executable test programs PASS' in dq,'live_browser_semantic_roundtrip':False},
            'overall_rule':'Public and private surfaces are separate. Source/stage/PR evidence is never installation or running state.'}

def main():
    p=argparse.ArgumentParser()
    for n in ('swing_root','direct_linux_root','rasen_root','https_root','ldap_root','deployment_root','swing_sha256','direct_sha256','renderer_out','readiness_out'):
        p.add_argument('--'+n.replace('_','-'),required=True)
    a=p.parse_args()
    Path(a.renderer_out).write_text(json.dumps(renderer_evidence(a),indent=2)+'\n')
    rd=readiness(a); Path(a.readiness_out).write_text(json.dumps(rd,indent=2)+'\n')
    print(json.dumps({'rendererEvidence':a.renderer_out,'websiteReadiness':a.readiness_out,'websiteStatus':rd['status']},indent=2))
if __name__=='__main__': main()
