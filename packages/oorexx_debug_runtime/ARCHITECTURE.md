# Architecture

```text
application / Wire UI / Alchemy JavaScript
                 |
          Debug Runtime objects
                 |
          DebugProvider SPI
         /        |         \
     GDB/MI      JDWP      DbgEng
                  |
                 ADB (optional Android transport)
```

## Rules

1. Debug protocol nouns stop at the provider boundary.
2. Breakpoints are registered interests in execution events, not application
   strings containing debugger commands.
3. Variable names are runtime data; `DebugScope~UNKNOWN` projects them.
4. Control and observation are separate. A successful continue/step request is
   not evidence that the target is running.
5. Provider-specific facilities are advertised as capabilities; they do not
   distort the common object model.
6. ADB is a target/transport route, not a debugger object hierarchy.
7. The same semantic objects are intended to project through Alchemy bridges;
   renderers/languages must not fork debugger semantics.
