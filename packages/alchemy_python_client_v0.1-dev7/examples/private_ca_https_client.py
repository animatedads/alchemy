"""Source example only: configure a real published HTTPS RPC endpoint first."""
from alchemy_python import PrivateCAHttpTransport, JsonRpcClient

# Replace the illustrative URL and PEM locations with exact deployment values.
transport = PrivateCAHttpTransport(
    'https://rpc.rasenfalcon.com/rpc',
    ca_file='/etc/alchemy/pki/rasenfalcon-private-ca.pem',
    client_cert_file='/etc/alchemy/pki/python-client.pem',
    client_key_file='/etc/alchemy/pki/python-client.key',
)
client = JsonRpcClient(transport)
# result = client.request('published.operation', {'key': 'value'})
