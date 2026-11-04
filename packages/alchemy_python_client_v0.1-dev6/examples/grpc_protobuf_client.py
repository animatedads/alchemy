"""Example only: requires an existing authenticated gRPC service endpoint."""
from google.protobuf.wrappers_pb2 import StringValue
import grpc
from alchemy_python import GrpcClient, GrpcMethod

# Do not use grpc.insecure_channel for public or sensitive endpoints.
CHANNEL = grpc.secure_channel('inventory.example.invalid:443', grpc.ssl_channel_credentials())
client = GrpcClient(CHANNEL)
client.register(GrpcMethod('inventory.get', '/demo.Inventory/Get',
                           StringValue.SerializeToString, StringValue.FromString))
client.register(GrpcMethod('inventory.watch', '/demo.Inventory/Watch',
                           StringValue.SerializeToString, StringValue.FromString, streaming=True))
client.freeze()
# Once a qualified endpoint is configured:
# reply = client.unary('inventory.get', StringValue(value='item-7'))
# for update in client.stream('inventory.watch', StringValue(value='item-7')): print(update.value)
