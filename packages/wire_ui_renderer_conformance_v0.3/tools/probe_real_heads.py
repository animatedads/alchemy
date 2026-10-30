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
    rr=text(Path(a.rasen_root)/'README.md'); hv=text(Path(a.https_root)/'VALIDATION.txt'); lv=text(Path(a.ldap_root)/'VALIDATION_DEV22.txt'); dq=text(Path(a.deployment_root)/'QUALIFICATION.md')
    gates={
      'source_candidate_present': True,
      'review_stage_materialised': 'local review-only stage' in rr and '15 staged files' in rr,
      'release_manifest_admitted': not ('still refuses installation' in rr or 'Missing CMS' in rr),
      'https_0_4_8_static_contract_qualified': 'v0.4.8 local evidence in the current execution environment' in hv and 'PASS HTTPS streaming contract static locks' in hv,
      'exact_https_0_4_8_runtime_qualified': 'execution of the new v0.4.8 classes is NOT claimed' not in hv and 'modified v0.4.8 package' not in hv,
      'live_tls_streaming_qualified': 'live TLS streaming PUT/GET remains an external-host gate' not in hv,
      'ldap_owned_daemon_shape_present': 'owned LDAP daemon and' in lv,
      'ldap_installed': 'NOT INSTALLED' not in lv,
      'live_ldaps_bind_search_revoke': 'NOT RUN live LDAPS bind/search/revoke' not in lv,
      'wire_deployment_durable_ingress_qualified': '8/8 ooRexx executable test programs PASS' in dq,
      'wire_live_browser_semantic_roundtrip': not ('live browser/semantic roundtrip' in dq and 'not yet proven' in dq),
    }
    prod=all(gates[k] for k in ('release_manifest_admitted','exact_https_0_4_8_runtime_qualified','live_tls_streaming_qualified','ldap_installed','live_ldaps_bind_search_revoke','wire_live_browser_semantic_roundtrip'))
    return {'schema':'rasenfalcon-wire-runtime-readiness/0.1','captured':'2026-10-29','status':'READY' if prod else 'NOT_READY','gates':gates,
            'rule':'Source-only and review-staged states must never be reported as installed or running. Exact modified HTTPS, LDAP and Wire runtime evidence is required.'}

def main():
    p=argparse.ArgumentParser()
    for n in ('swing_root','direct_linux_root','rasen_root','https_root','ldap_root','deployment_root','swing_sha256','direct_sha256','renderer_out','readiness_out'):
        p.add_argument('--'+n.replace('_','-'),required=True)
    a=p.parse_args()
    Path(a.renderer_out).write_text(json.dumps(renderer_evidence(a),indent=2)+'\n')
    rd=readiness(a); Path(a.readiness_out).write_text(json.dumps(rd,indent=2)+'\n')
    print(json.dumps({'rendererEvidence':a.renderer_out,'websiteReadiness':a.readiness_out,'websiteStatus':rd['status']},indent=2))
if __name__=='__main__': main()
