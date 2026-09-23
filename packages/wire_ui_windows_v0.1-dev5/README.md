# Wire UI Windows v0.1-dev2

Native Windows renderer for the renderer-neutral Wire application model.

Dev2 crosses the first real Windows runtime boundary: Win32 controls translate native activity into semantic Wire events; a resident ooRexx 5.3.0 r13196 interpreter executes the shared Wire event/controller/binding mechanism. The renderer itself does not include ooRexx or business behaviour.

## Architecture lock

`HWND` is renderer state, never application identity. `WM_*` is renderer input, never a Wire application event. Native activation is translated to a semantic trigger (`Click` in the qualification path). ooRexx behaviour receives `WireApplicationEvent` and remains Windows-neutral.

Wire Windows does **not** use ooDialog. The staging script deliberately removes ooDialog binaries/classes from the private runtime as a dependency-negative qualification gate.

## Build

Use Visual Studio/MSVC matching the supplied x86-64 ooRexx import libraries:

```
cmake -S . -B build -A x64 -DOOREXX_ROOT=C:\path\to\oorexx-5.3.0-13196.windows.x86_64-portable-release
cmake --build build --config Release
```

Stage the EXE, `rexx/`, and the private runtime under one application directory. `wire_ui_windows.exe` resolves `runtime\\oorexx\\bin` privately and starts ooRexx with `RexxCreateInterpreter`; it does not require a globally installed ooRexx.

## Qualification slice

The dev2 button has semantic identity `qualifyButton`. A native `BN_CLICKED` becomes `qualifyButton / Click`, crosses into `WireWindowsBootstrap.rex`, constructs the normal `WireApplicationEvent`, dispatches through `WireApplicationController` + `WireBinding`, and returns `WIRE_EVENT|qualifyButton|Click` to the Windows host.

This is deliberately a narrow vertical slice before Builder-driven materialization and authoritative state projection are added.

## dev3

The host no longer hard-codes the qualification controls. It materializes `definitions/windows-qualification.wiredef`, maps stable semantic IDs to private native handles, and translates Win32 activity back to semantic source/trigger pairs. The Rexx behaviour changes `status.text` through `event~ui`; the native host receives a temporary semantic patch envelope and projects it through the renderer. HWND/WM_* values never enter application Rexx. ooDialog and ooRexx GTK are explicitly outside the Wire application architecture.

## dev5

- semantic dispatch now returns and applies a batch of renderer-neutral property patches;
- qualification behaviour changes both status and button text through `event~ui`;
- native Windows layout remains renderer policy and uses Segoe UI without leaking geometry into the Wire definition;
- `scripts/stage-app.ps1` assembles the executable, semantic definitions, Rexx behaviour, contracts, assets and private ooRexx runtime into one runnable application tree;
- ooDialog remains deliberately absent from the staged runtime and is not a Wire dependency.

## dev5 resident semantic authority
The embedded interpreter now retains the authoritative Wire application model across native events. Repeated native clicks therefore mutate persistent semantic state rather than reconstructing application truth for each dispatch. The qualification behaviour exposes this visibly through a semantic activation counter.
