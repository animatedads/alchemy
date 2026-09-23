"ooRexx Pharo Alchemy v0.1-dev6 - Pharo-side protocol model"

Object subclass: #AlchemyRexxBridge
    instanceVariableNames: ''
    classVariableNames: ''
    package: 'Alchemy-ooRexx'.

"Send one Smalltalk message to the live ooRexx object identified by aHandle.
Subclasses own exception translation, authority checks and synchronous re-entry."
AlchemyRexxBridge >> sendToRexx: aHandle selector: aSelector arguments: anArray [
    self subclassResponsibility
]

"Export an ordinary Pharo object to ooRexx while preserving resident identity."
AlchemyRexxBridge >> exportPharoObject: anObject [
    self subclassResponsibility
]

"Return the interned Pharo proxy for an ooRexx identity, never a value snapshot."
AlchemyRexxBridge >> importRexxObject: aHandle [
    self subclassResponsibility
]

"Compare two exported ooRexx identities without substituting value equality."
AlchemyRexxBridge >> sameRexxIdentity: firstHandle as: secondHandle [
    self subclassResponsibility
]


Object subclass: #AlchemyRexxObject
    instanceVariableNames: 'bridge handle'
    classVariableNames: ''
    package: 'Alchemy-ooRexx'.

"Create a proxy bound to exactly one bridge and one live ooRexx identity."
AlchemyRexxObject class >> bridge: aBridge handle: aHandle [
    ^ self new bridge: aBridge; handle: aHandle; yourself
]

"Install the bridge used for all messages crossing back into ooRexx."
AlchemyRexxObject >> bridge: anObject [ bridge := anObject ]

"Install the opaque, generation-safe identity supplied by the bridge."
AlchemyRexxObject >> handle: anObject [ handle := anObject ]

"Return this proxy's bridge without exposing transport implementation details."
AlchemyRexxObject >> bridge [ ^ bridge ]

"Return this proxy's opaque ooRexx identity handle."
AlchemyRexxObject >> handle [ ^ handle ]

"Forward an unresolved Smalltalk Message to ooRexx.  Preserve the real selector
and argument objects; do not flatten the Message into JSON or a method-table key."
AlchemyRexxObject >> doesNotUnderstand: aMessage [
    ^ bridge
        sendToRexx: handle
        selector: aMessage selector
        arguments: aMessage arguments
]
