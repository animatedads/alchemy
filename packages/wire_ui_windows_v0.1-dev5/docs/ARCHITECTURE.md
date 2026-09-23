# Windows renderer architecture

Windows is another Wire UI renderer, not another application architecture.

`Win32 control -> native capture -> queued UI_ACTION -> WireApplicationEvent -> WireApplicationController -> ooRexx behaviour -> authoritative snapshot/patch -> Win32 renderer`

The application-facing contract remains **WIRE-UI/0.1** and the direct renderer ABI remains **4**. `source`, `trigger`, semantic context, view/revision identity and application element identity are preserved. Native HWND values never become business identity.

The renderer may lay out the same semantic tree differently from Web, Swing, GTK, Android or direct Linux. It may not change action meaning, permissions, business state, journey authority, foreign-object semantics, or application identity.

## Foreign languages

A Rexx event handler may invoke any supported Alchemy/foreign object exactly as on the other targets. The Windows renderer does not special-case Python, JavaScript, Java, .NET, Rust, Ruby or other bridges. Language plugins are dependencies of the ooRexx application/runtime layer and are packaged by capability lock.

## Runtime delivery

The installed application carries a private Windows ooRexx runtime under `runtime\oorexx`. This avoids requiring a machine-wide ooRexx install and avoids mutating PATH. Dev1 includes the staging contract but not Windows ooRexx binaries because the supplied runtime artifact is an Ubuntu `.deb`, not a Windows distribution.

## Thread/event rule

No Win32 window procedure executes application logic or blocks on Rexx/foreign code. It captures native state and queues the semantic action. This mirrors the Swing rule that listeners only capture local state and enqueue `UI_ACTION`.
