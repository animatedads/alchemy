# Handover — FederationBank Staff Wire UI v0.1

## What is now implemented

An early server-authoritative Staff Banking workspace is present. It deliberately
starts small:

- staff/session/branch/desk context is projected from the server;
- durable Staff Channel work summary/list/detail is visible;
- work filter/sort/select/open uses Wire UI v0.17 workspace result authority;
- the first mutation is `CUSTOMER.TRANSFER.SUBMIT` only;
- exact Staff Method Permission is checked before a Staff Channel request exists;
- Staff Channel then independently obtains Staff Authority and routes to Core
  Banking; the UI never receives or acts as bearer authority.

The default `./start.sh` opens a clearly marked non-authoritative visual fixture.
The live shell is `web/index.html`, and `FederationBankStaffWireWebGatewayService`
provides the ooRexx-side Wire UI/Queue Fabric seam.

## Authority invariants

Do not collapse these layers in later UI work:

1. authentication = attribution/integrity evidence;
2. Access Control = coarse permission to enter the Staff Banking domain;
3. Method Permission = exact principal/object/class/method invocation authority;
4. Staff Authority = separate banking-business authority;
5. Core Banking = final authority for applicable Core commands.

An enabled control, renderer role, client-side state or cached definition grants
none of the above.

## Recommended next UI increment

Add checker work as a server-authoritative journey over existing
`APPROVAL_REQUIRED` durable work. The checker action must use its own exact method
permission and checker Staff Authority; never let the maker session complete its
own approval merely because a button is rendered. After that, add the dedicated
Staff browser/WebSocket/Web Gateway end-to-end acceptance fixture, then extend
beyond transfer one business action at a time.
