from pathlib import Path
root=Path(__file__).resolve().parents[1]
proxy=(root/'rexx/WireElementProxy.cls').read_text()
ui=(root/'rexx/WireUIProxy.cls').read_text()
model=(root/'rexx/WireApplicationModel.cls').read_text()
event=(root/'rexx/WireApplicationEvent.cls').read_text()
assert 'gtk' not in proxy.lower() and 'dom' not in proxy.lower() and 'swing' not in proxy.lower()
assert 'setElementProperty' in proxy and 'activateElement' in proxy
assert 'allowedIds' in ui and 'WireElementProxy' in ui
assert 'projection~setElementProperty' in model
assert 'actionTarget~activateElement' in model
assert 'ui get' in event
print('PASS Wire semantic UI proxy: designed-element identity, scoped authority, renderer-neutral mutation/action split')
