# UK legislation XML: where it is

Architecture: Tom Dyer. Placed by Claude (Opus 5.5), 2026-10-30, on Tom's instruction ("we can put these all up to git").

`law/README.md` names `law/uk/ukpga/<year>/<chapter>/data.xml` as the target paths. The six Acts are not there, because GitHub push protection rejects them in that folder. Every CLML file carries `key-<32 hex>` identifiers (commentary ids, `CommentaryRef`, `ChangeId`, `EffectId`), and those match GitHub's Mailgun API key pattern. They are identifiers, not credentials: 389 lines across the six files, all in those attributes. `.github/secret_scanning.yml` (Tom Dyer, `629229a1`) exempts one folder for exactly this, so the files are there:

| Act | File | SHA-256 | Valid from |
|---|---|---|---|
| Fraud Act 2006 | `packages/oorexx_slam_v0.1/tests/law/source/fraud2006.xml` | b3a267d809d0b3e1a6a872b29c4192bdd47515ca70d8335d3c46f6714a0c4107 | 2023-02-07 |
| Theft Act 1968 | `packages/oorexx_slam_v0.1/tests/law/source/theft1968.xml` | 34afb7e66bd1c99c6e79af6c9c54f58db32cc5227a9595da7c7dd9014ee3cefc | 2013-05-28 |
| Criminal Law Act 1977 | `packages/oorexx_slam_v0.1/tests/law/source/cla1977.xml` | c5dad54f1134d9e7aaa9cbb7ac604fb16c3fe9a127e93df56fb20d14ad27c73e | 2020-12-31 |
| Financial Services and Markets Act 2000 | `packages/oorexx_slam_v0.1/tests/law/source/fsma2000.xml` | bfdbfd4948f7ae2dddd1b039dd82770c99eb8737b11579cbd458dec45e2b878e | 2026-07-15 |
| Social Security Administration Act 1992 | `packages/oorexx_slam_v0.1/tests/law/source/ssaa1992.xml` | 9b9c4871cfb4862b5c10a05becef055fe1cd1216cf4097b07108b10559b213ed | 2026-10-26 |
| Proceeds of Crime Act 2002 | `packages/oorexx_slam_v0.1/tests/law/source/poca2002.xml` | 63dc459ac7a8524d88a27a1008d8c53a077b2783219a156822e79bf08006db97 | 2026-06-30 |
| Computer Misuse Act 1990 | `packages/oorexx_slam_v0.1/tests/law/source/cma1990.xml` | 83edcadf896683b9e1c01e857e0598364ba51d271a2ffef82b752671cd986958 | 2023-02-07 |

All seven were fetched by Tom Dyer from legislation.gov.uk and attached, on 2026-10-29 (CMA) and 2026-10-30 (the six). This session's network cannot reach legislation.gov.uk. Each is the latest revised text from the date shown; none is checked as the text in force on an event's date. More detail, including each candidate section's extent: `packages/oorexx_slam_v0.1/tests/law/source/MANIFEST_LEGISLATION.md`.

If they should also be under `law/uk/`, that needs the same one-line exemption for `law/uk/**/*.xml`, added by the repository owner. Nobody else should change the scanning settings.
