# Java sphere v0.1

Requires an LLM Gopher engine that supports `language-module` objects (v0.17-dev1 or later).

Purpose:
- first-class Java source examination and exact-symbol semantics;
- compile evidence through `javac`;
- grouped Java language-rule evidence;
- project-grounded Swing and JMS lessons from the ooRexx API roll-up.

Grounded delivered evidence:
- Wire UI Swing v0.2-dev3
- Wire UI Swing test app v0.2-dev6
- FederationBank Java ATM v0.1.9
- ooRexx JMS Queue Bridge v0.1-dev7-fb1

This sphere deliberately distinguishes portable Java guidance from project-specific choices such as the ATM's reflective JMS adapter and AUTO_ACKNOWLEDGE synchronous request/reply session.

Start:

    ./gopher --profile java context java --full
    ./gopher --profile java search swing --sphere java
    ./gopher --profile java search jms --sphere java
    ./gopher --profile java lookup topic=interop --sphere java --corpus java.lessons
