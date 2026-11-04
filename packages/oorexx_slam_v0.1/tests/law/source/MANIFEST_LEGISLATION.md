# Legislation sources: manifest

Architecture: Tom Dyer. Files fetched by Tom Dyer from legislation.gov.uk and attached: `cma1990.xml` on 2026-10-29; the other six on 2026-10-30, as requested by ChatGPT (GPT-6) in OFFENCE-001 (REQ-00002591). This session could not fetch them: its network allowlist refuses www.legislation.gov.uk (HTTP 403 on CONNECT), and ChatGPT's `fetch_uk_legislation_clml.py` failed the same way for all six. Manifest written and checked by Claude (Opus 5.5), 2026-10-30.

**Which copies are in this repository.** All seven are committed here (2026-10-30, on Tom's instruction). This is the folder push protection exempts for CLML's `key-<32 hex>` identifiers; see `law/uk/WHERE_THE_UK_XML_IS.md`. The NSW, Commonwealth and New York sources are in `law/source_corpus/nsw_ny_20261030/`.

Each file is the latest revised text, valid from the date shown (`dct:valid`). **None of them is the text in force on the date of an alleged act.** The Mrs P events have no dates, so no as-at check has been run. For a dated case, fetch the version for that date: `https://www.legislation.gov.uk/<type>/<year>/<chapter>/<yyyy-mm-dd>/data.xml`.

Checks run on every file: well-formed (`xmllint --noout`); the root element is `<Legislation>`; `DocumentURI` and `dc:title` name the Act asked for; SHA-256 computed on the bytes as received.

| File | Act | Valid from | Bytes | SHA-256 | DocumentURI |
|---|---|---|---|---|---|
| `cma1990.xml` | Computer Misuse Act 1990 | 2023-02-07 | 269032 | 83edcadf896683b9e1c01e857e0598364ba51d271a2ffef82b752671cd986958 | http://www.legislation.gov.uk/ukpga/1990/18 |
| `fraud2006.xml` | Fraud Act 2006 | 2023-02-07 | 151971 | b3a267d809d0b3e1a6a872b29c4192bdd47515ca70d8335d3c46f6714a0c4107 | http://www.legislation.gov.uk/ukpga/2006/35 |
| `theft1968.xml` | Theft Act 1968 | 2013-05-28 | 282679 | 34afb7e66bd1c99c6e79af6c9c54f58db32cc5227a9595da7c7dd9014ee3cefc | http://www.legislation.gov.uk/ukpga/1968/60 |
| `cla1977.xml` | Criminal Law Act 1977 | 2020-12-31 | 671163 | c5dad54f1134d9e7aaa9cbb7ac604fb16c3fe9a127e93df56fb20d14ad27c73e | http://www.legislation.gov.uk/ukpga/1977/45 |
| `fsma2000.xml` | Financial Services and Markets Act 2000 | 2026-07-15 | 20878291 | bfdbfd4948f7ae2dddd1b039dd82770c99eb8737b11579cbd458dec45e2b878e | http://www.legislation.gov.uk/ukpga/2000/8 |
| `ssaa1992.xml` | Social Security Administration Act 1992 | 2026-10-26 | 5520831 | 9b9c4871cfb4862b5c10a05becef055fe1cd1216cf4097b07108b10559b213ed | http://www.legislation.gov.uk/ukpga/1992/5 |
| `poca2002.xml` | Proceeds of Crime Act 2002 | 2026-06-30 | 11896182 | 63dc459ac7a8524d88a27a1008d8c53a077b2783219a156822e79bf08006db97 | http://www.legislation.gov.uk/ukpga/2002/29 |

## Extent of the candidate sections

Read from each section's own markup by `SlamLegislation~section`; the Act-level `RestrictExtent` (E+W+S+N.I. on all seven) is not used.

| Section | England and Wales | Scotland |
|---|---|---|
| Computer Misuse Act 1990 ss.1, 2, 3ZA | yes | yes (s.1 has words for Scotland only) |
| Fraud Act 2006 ss.2, 3, 4, 6, 7 | yes | **no** |
| Theft Act 1968 ss.1, 21, 24A | yes | **no** |
| Criminal Law Act 1977 s.1 | yes | **no** |
| FSMA 2000 ss.19, 23 | yes | yes |
| SSAA 1992 ss.111A, 112 | yes | yes |
| POCA 2002 ss.327, 328, 329 | yes | yes |

So, for a case in Scotland, the nearest offences to these (fraud, theft, extortion, conspiracy) are common-law crimes, with no XML. Those rule packs are OUT_OF_SCOPE for extent S. until an agreed source for Scots common law is chosen.

Licence of the sources: Open Government Licence v3.0, Crown copyright.
