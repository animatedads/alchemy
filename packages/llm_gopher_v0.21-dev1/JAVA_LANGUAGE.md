# Java language module and sphere

LLM Gopher v0.17-dev1 adds a first-class Java language module and a `java` sphere.

Start with:

    ./gopher --profile java context java --full
    ./gopher --profile java language describe java
    ./gopher --profile java examine source WireSwingEdt.java --in <archive-or-directory> --symbol WireSwingEdt
    ./gopher --profile java exec source.java.compile path=Sample.java release=17
    ./gopher --profile java rules check Sample.java --language java

The Java sphere is grounded in delivered project evidence from:
- Wire UI Swing v0.2-dev3 (and test-app v0.2-dev6)
- FederationBank Java ATM v0.1.9
- ooRexx JMS Queue Bridge v0.1-dev7-fb1

It separates deterministic language checks from Swing/JMS lessons that require architecture or intent.
