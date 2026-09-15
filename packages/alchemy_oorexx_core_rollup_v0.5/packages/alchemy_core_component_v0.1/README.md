# Alchemy Core Component v0.1

Common ooRexx operational base for the Alchemy integration stack. It subclasses `AlchemyObject` v0.4.3 so transport/model/execution objects inherit identity, lifecycle telemetry, method contracts, requirements, inspection, security and sealed-evidence surfaces without reimplementing them.

Pure static helper classes remain static helpers. Stateful/value/service objects in the core packages inherit this class.
