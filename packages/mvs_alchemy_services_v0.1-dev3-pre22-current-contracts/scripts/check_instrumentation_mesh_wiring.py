#!/usr/bin/env python3
from pathlib import Path
root=Path(__file__).resolve().parents[1]
adapter=(root/'HOST/src/MasInstrumentationAdapter.cls').read_text()
gateway=(root/'HOST/src/MasLiveGateway.cls').read_text()
harness=(root/'scripts/qualify_ed209c_ed209z_services.sh').read_text()
launcher=(root/'HOST/bin/mas-live-gateway-instrumented.rex').read_text()
pub=(root/'HOST/tests/mas_instrumentation_publication.rex').read_text()
required_adapter=['InstrumentationEmitter','requestAccepted','requestCompleted','requestFailed','bytesIn','bytesOut','snapshot','semanticRef','capability','mas.sessions.active','mas.operation.accepted.total','operation_code','service_role']
required_gateway=['observer~frameReceived','observer~requestAccepted','observer~requestCompleted','observer~requestFailed','observer~frameSent']
required_harness=['oorexx_instrumentation_mesh_v0.1-dev8.zip','mas-live-gateway-instrumented.rex','mas_instrumentation_publication.rex','instrumentation.tsv','MAS_PRE22_LIVE','semantic_ref','guest_id=ED209Z']
required_launcher=['MAS_INSTRUMENTATION_GUEST_ID','sample[\'dimensions\']','semantic_ref']
required_pub=['InstrumentationRegistry','InstrumentationService','InstrumentationCollector','InstrumentationPublisher','latestBySemanticRef','collector~series']
for label,text,items in [('adapter',adapter,required_adapter),('gateway',gateway,required_gateway),('harness',harness,required_harness),('launcher',launcher,required_launcher),('publication',pub,required_pub)]:
    missing=[x for x in items if x not in text]
    if missing: raise SystemExit(f'FAIL {label}: missing {missing}')
print('PASS INSTRUMENTATION_MESH_WIRING PRE22')
