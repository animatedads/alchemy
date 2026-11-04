# Dependencies

Required qualification baseline: Open Object Rexx 5.3.0 r13196.

No external runtime/library dependencies are introduced by dev3. Domain libraries continue to own domain-specific `TemplateFormatter` implementations; StringTemplate does not acquire hard dependencies on Units, time, money, UI, persistence or application models.
