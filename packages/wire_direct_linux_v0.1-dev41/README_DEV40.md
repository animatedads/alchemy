# Wire Direct Linux dev40

Builder state-machine correction: switching elements invalidates the selected event. Both manual and editor-returned bindings now share a single duplicate-ID check. This is a source-level compatibility fix, not a new renderer authority. See `QUALIFICATION_DEV40.txt`.
