# Citi multi-listed reference fixture

Source: Citigroup Markets & Securities Services, *Citi ISO 15022 Settlement Instruction Requirements for Multi-Listed Securities (as of SR2014)*.

Public source URI:
`https://www.citigroup.com/mss/sa/dcc/swift/iso_15022/docs/2011/dual_list_sec_2.pdf`

The regression deliberately models three facts from the source rather than treating an ISIN as a unique settlement identity:

1. place of listing can select the intended line for a multi-listed ISIN;
2. where multiple London lines exist, denomination currency can be required in addition to place of listing;
3. place of safekeeping can remain a separate operational discriminator for holdings/custody routing.

The fixture uses fictional ISIN/SEDOL-like identifiers.  It does not claim that the example security in the source is current reference data.

The source locations retained by the fixture are evidence locators, not parsed legal conclusions:

- `P1-XLON` / `P1-XDUB` — place-of-listing examples;
- `P2-XLON-GBP` / `P2-XLON-USD` — denomination disambiguation;
- `P4-SAFE` — place-of-safekeeping examples.
