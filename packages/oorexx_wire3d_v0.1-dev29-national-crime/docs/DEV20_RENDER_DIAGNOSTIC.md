# dev20 renderer pixel diagnostic

The renderer now qualifies more than clip mathematics. After each draw it reads one framebuffer pixel at each semantic object centre. The diagnostic reports NDC, RGBA, WebGL renderer and `gl.getError()`.

A green/`data-pass=true` diagnostic requires all clipped-in semantic centres to have non-background pixels and GL_NO_ERROR. This is renderer evidence only; it does not create semantic application state. `preserveDrawingBuffer` is enabled temporarily for qualification and can be removed after the visual pipeline is accepted.
