# Dev7: private CA HTTPS client profile (29 October 2026)

## Implemented
`PrivateCAHttpTransport` is an opt-in JSON-RPC 2.0 HTTPS transport for Rasen Falcon services when their authenticated HTTPS server publishes an RPC endpoint. It is not the server or an LDAP client. The platform HTTPS server and LDAP Identity own server identity/authentication and authorization, RPC Service Core owns published method admission, ConnectSelector owns invocation route, and Serialization Selector owns encoding. The Python SDK consumes these surfaces, it does not replace them.

The client constructs an SSLContext(PROTOCOL_TLS_CLIENT) from scratch and loads only a caller-named private CA PEM. It requires hostname verification and CERT_REQUIRED; may load a caller-provided client certificate/key for mutual TLS; supports optional server-issued bearer credentials only under HTTPS. It prohibits redirects and ambient proxy use and refuses insecure scheme/absent CA. It never retries on timeout/uncertain remote execution.

## Example
```python
from alchemy_python import PrivateCAHttpTransport, JsonRpcClient
transport = PrivateCAHttpTransport(
    "https://rpc.rasenfalcon.com/rpc",  # illustrative host: must be deployed and qualified
    ca_file="/etc/alchemy/pki/rasenfalcon-private-ca.pem",
    client_cert_file="/etc/alchemy/pki/python-client.pem",
    client_key_file="/etc/alchemy/pki/python-client.key",
)
client = JsonRpcClient(transport)
# client.request("published.operation", {"key": "value"})
```
No live RPC endpoint at that illustrative host is asserted. For local direct/queue/RTO2 select through ConnectSelector; this module handles only the deliberately selected HTTP JSON-RPC client transport.

## Executed qualification
Python 3.13 test suite: 93 passing (87 inherited + 6 private-CA tests). Openssl-generated ephemeral test CA and server/client certificates; real TLS loopback handshakes; certificate-chain rejection; mTLS client certificate mandatory against server that requires it; redirect refusal; invalid certificate/credential configurations refused. The test server is Python, not ooRexx. Tests prove only Python behavior; remote platform HTTPS, LDAP, and integration with the ooRexx runtime remain NOT RUN.

## Security boundaries and release gates
- Never use ambient public CA roots or disable hostname verification as a fallback.
- Client auth does not itself establish LDAP access rights: server must authenticate and authorize identity against LDAP Identity.
- No raw credentials or tokens in URLs/logging. Client private keys must be provisioned by the platform's secret authority; no sample keys delivered.
- Do not infer production service installation from a successful TLS handshake to a local fixture.
- Production acceptance requires live HTTPS server v0.4.8 (or superseding), the private CA, the LDAP Identity service, published JSON-RPC service, ConnectSelector policy, and exact naming/certificate provenance. Keep invocation receipts distinct from queue/job completion.
