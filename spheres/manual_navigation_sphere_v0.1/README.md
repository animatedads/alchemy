# Manual Navigation sphere v0.1

Shared LLM operations guide for Gopher's bounded PDF/HTML reference reader.

Typical cycle:

    gopher reference find <file-or-url> <string>
    gopher reference locate <pdf> --reference-page N --approx-page M
    gopher reference read <source> --page P
    gopher reference move <source> --page P 1

The language/manual-specific sphere tells you where to look; this sphere tells you how to navigate the primary document without guessing.
