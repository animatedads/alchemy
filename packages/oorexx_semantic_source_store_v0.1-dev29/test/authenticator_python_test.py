import base64, json, subprocess, tempfile
from pathlib import Path
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

def dec(s):
    return base64.urlsafe_b64decode(s + '=' * (-len(s) % 4))

root = Path(__file__).resolve().parents[1]
tool = root / 'tools' / 'ssc_authenticator.py'
with tempfile.TemporaryDirectory() as td:
    td = Path(td)
    key = td/'key.pem'
    out = subprocess.check_output(['python3', str(tool), 'keygen', '--key-id','CHATGPT-SSC-001','--private-key',str(key)], text=True)
    ident = json.loads(out)
    ch = {
      'schema':'semantic-source.auth.challenge/1',
      'challenge_id':'c-1','key_id':'CHATGPT-SSC-001','audience':'semantic-source-mcp',
      'action':'source.get_package','resource_id':'oorexx://family/Family',
      'nonce':'abc123','issued_at':'2026-09-27T17:00:00Z','expires_at':'2026-09-27T17:02:00Z'
    }
    cp = td/'challenge.json'; cp.write_text(json.dumps(ch))
    token = json.loads(subprocess.check_output(['python3',str(tool),'sign','--private-key',str(key),'--challenge',str(cp)], text=True))
    msg = '\n'.join(['SSC-AUTH-1',ch['challenge_id'],ch['key_id'],ch['audience'],ch['action'],ch['resource_id'],ch['nonce'],ch['issued_at'],ch['expires_at']]).encode()
    Ed25519PublicKey.from_public_bytes(dec(ident['public_key_b64url'])).verify(dec(token['signature_b64url']),msg)
    assert token['challenge_id']=='c-1'
    print('AUTHENTICATOR PYTHON TEST: PASS')
