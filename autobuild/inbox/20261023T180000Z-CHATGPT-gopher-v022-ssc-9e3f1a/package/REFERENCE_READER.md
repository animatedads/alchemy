# Reference Document Reader

Use Gopher directly against PDF or HTML references on disk or over HTTP(S).

Examples:

    gopher reference find rexxref.pdf "USE STRICT ARG"
    gopher reference read rexxref.pdf --page 61 --reference-page 47
    gopher reference move rexxref.pdf --page 61 1
    gopher reference move rexxref.pdf --page 61 -1
    gopher reference move rexxref.pdf --page 61 5
    gopher reference locate rexxref.pdf --reference-page 47 --approx-page 61 --window 20

HTML:

    gopher reference find https://docs.python.org/3.13/reference/ "data model"
    gopher reference read https://docs.python.org/3.13/reference/ --section 2
    gopher reference move https://docs.python.org/3.13/reference/ --section 2 1

PDF navigation uses physical PDF pages. `reference_page_hint` preserves a printed/manual page citation without claiming the physical index is identical.

Every read is bounded and returns document identity, SHA-256, location, text truncation metadata and navigation.
