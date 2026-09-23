# dev29.3

Adds generic search/navigation presentation to the national map:

- progressive geography search over LSOA code/name
- search result selects the same semantic area as polygon clicking
- selection frames/zooms the chosen geometry
- generic crime-category value search from the supplied analytics catalogue
- HOME and FRAME navigation
- no separate searched-area state

Crime category selection is presentation state in this increment; category-specific
national compact frames remain an analytics-provider request, and are not fabricated
inside the renderer.
