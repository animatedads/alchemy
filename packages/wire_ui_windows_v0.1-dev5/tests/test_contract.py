from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
def test_abi():
 s=(R/'include/wire_renderer.h').read_text(); assert '#define WIRE_RENDERER_ABI 4u' in s
 c=json.loads((R/'contracts/wire-windows-target.json').read_text()); assert c['protocol']=='WIRE-UI/0.1' and c['rendererAbi']==4
def test_shared_event_shape():
 s=(R/'rexx/WireApplicationEvent.cls').read_text()
 for x in ['source','trigger','context','timestamp','rendererContext','ui']: assert x in s
def test_renderer_has_no_oorexx_or_business_logic():
 s=(R/'src/wire_windows_renderer.cpp').read_text()
 for x in ['oorexxapi','RexxCreateInterpreter','WireApplicationController','ooDialog']: assert x not in s
def test_native_event_becomes_semantic_event():
 s=(R/'src/wire_windows_renderer.cpp').read_text(); assert 'BN_CLICKED' in s and '"Click"' in s and 'semanticId' in s and 'PostMessageW' in s and 'WIRE_WM_SEMANTIC_EVENT' in s
def test_real_embedded_interpreter_path():
 s=(R/'src/wire_windows_rexx_host.cpp').read_text(); assert 'RexxCreateInterpreter' in s and 'CallProgram' in s
 b=(R/'rexx/WireWindowsBootstrap.rex').read_text(); assert '.WireApplicationEvent~new' in b and '.WireApplicationController~new' in b
def test_private_runtime():
 p=json.loads((R/'packaging/app-package.json').read_text()); assert p['privateRuntime']=='runtime\\oorexx'
def test_oodialog_is_not_dependency():
 alltext='\n'.join(p.read_text(errors='ignore') for p in list((R/'src').glob('*'))+list((R/'rexx').glob('*')))
 assert '::requires \"ooDialog' not in alltext and 'oodialog.dll' not in alltext.lower()
 stage=(R/'scripts/stage-windows-runtime.ps1').read_text(); assert 'oodialog.dll' in stage and 'Remove-Item' in stage
def test_proxy_is_shared_renderer_neutral_contract():
 assert (R/'rexx/WireUIProxy.cls').exists() and (R/'rexx/WireElementProxy.cls').exists()
def test_dev3_materializes_semantic_definition_not_host_widgets():
 h=(R/'src/wire_windows_host.cpp').read_text()
 assert 'windows-qualification.wiredef' in h and 'materialize' in h
 assert '"qualifyButton"' not in h
 d=(R/'definitions/windows-qualification.wiredef').read_text()
 assert 'qualifyButton|BUTTON|appWindow|' in d and 'status|LABEL|appWindow|' in d
def test_dev3_rexx_mutates_through_wire_ui_proxy():
 b=(R/'rexx/WireWindowsBootstrap.rex').read_text()
 assert 'event~ui~byId("status")~text =' in b
 assert 'WIRE_PATCH|status|text|' in b
 code='\n'.join(x for x in b.splitlines() if not x.lstrip().startswith('/*') and not x.lstrip().startswith('*'))
 assert 'HWND' not in code and 'WM_' not in code
def test_gtk_and_oodialog_are_not_application_dependencies():
 alltext='\n'.join(p.read_text(errors='ignore') for p in list((R/'src').glob('*'))+list((R/'rexx').glob('*')))
 assert '::requires "ooDialog' not in alltext and '::requires "gtk' not in alltext.lower()
def test_dev4_patch_batch_is_semantic_and_multi_property():
 b=(R/'rexx/WireWindowsBootstrap.rex').read_text()
 h=(R/'src/wire_windows_host.cpp').read_text()
 assert b.count('WIRE_PATCH|') >= 2
 assert 'qualifyButton|text|' in b
 assert 'applyPatchBatch' in h and 'std::getline(lines,line)' in h

def test_dev4_has_runnable_application_stager():
 s=(R/'scripts/stage-app.ps1').read_text()
 assert 'stage-windows-runtime.ps1' in s
 assert 'wire-ui.exe' in s and 'definitions' in s and 'rexx' in s


def test_dev5_semantic_model_is_resident_not_rebuilt_per_click():
 b=(R/'rexx/WireWindowsBootstrap.rex').read_text()
 assert '.environment~hasIndex(modelKey)' in b
 assert '.environment[modelKey] = model' in b
 assert 'activationCount' in b
 assert 'semantic activation' in b

def test_dev5_generic_semantic_property_access_stays_renderer_neutral():
 p=(R/'rexx/WireElementProxy.cls').read_text()
 assert '::method getProperty' in p and '::method setProperty' in p
 for forbidden in ['HWND','WM_','GtkWidget','ooDialog']:
  assert forbidden not in p
