# Registered extension boundary

The core library has no XMPP-extension registry because the base service should
not become an XMPP feature catalogue.

A component that needs an extension should ship a separate registered plugin
layer with:

1. its own semantic object model;
2. its own provider contract;
3. its own capability discovery;
4. its own transient Intention surface;
5. an XMPP adapter hidden behind that provider when XMPP is the chosen carrier.

For example, a future group-conversation feature would be a
`GroupConversationProvider`, not new methods on `Messaging`, and it would be
absent from Intention discovery unless its plugin/provider were currently
available and authorised.
