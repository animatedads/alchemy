"""Illustrative adapter only: NOT Connect Selector's unpublished actual ABI."""
from alchemy_python import (AlchemySession, Operation, ServiceContract,
                            SelectorClient, VirtualServiceClassFactory)

class DemoSelectorAdapter:
    def request(self, intent):
        # Production: delegate to Connect Selector's accepted implementation.
        return {'illustration_only': True, 'service': intent.service,
                'method': intent.operation, 'semantics': intent.semantics}
    def notify(self, intent):
        # No delivery/processing confirmation for a notification.
        return None

contract = ServiceContract('catalog', '1', (
    Operation('lookup', 'catalog.lookup'),
    Operation('hint', 'catalog.hint', kind='notification')))
Catalog = VirtualServiceClassFactory.make('Catalog', contract)
catalog = Catalog(SelectorClient(DemoSelectorAdapter()), contract)
print(catalog.lookup({'key': 'SKU-123'}))
catalog.hint({'key': 'SKU-123'})
