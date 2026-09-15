# Recovery model

The complete Branch Day domain object, including opening evidence, closing evidence, physical positions and control totals, is encoded with Queue Fabric graph persistence. Restart restores the exact historical evidence rather than reconstructing an earlier opening/closing decision from today's source systems.

Service events are outboxed after durable state mutation. Delivery failure does not roll back a certified domain transition; undelivered events remain pending for retry.
