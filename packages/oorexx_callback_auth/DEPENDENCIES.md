# Dependencies

Qualification runtime:

- ooRexx 5.3.0 r13196 debug amd64 package
- SHA-256 `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`

Required core dependencies:

- ooRexx Crypto v0.8.3
  - archive SHA-256 `5ebcab81493287499719f98920cb190d37afc79992cb34c7772d5392f63b9b49`
- ooRexx Crypto Authentication Primitives v0.1-dev1 (`crypto.auth/0.1`)
- ooRexx standard `json.cls` from the runtime

Required for the external HTTPS OIDC adapter qualification:

- ooRexx API Client v0.4.1
  - archive SHA-256 `9542e8cb9fcdefd42f32115a63034a7cc75ce8580a1356b6f58945e3f0401c37`

Optional integration:

- ooRexx Secret Broker v0.2
  - archive SHA-256 `c063a8e863547e8d5af427daee9b887590fdad76a65bc042b8f853acfd51e623`

Source roll-up used to recover the dependency archives:
`oorexxapis(20260921-192614).zip`, SHA-256 `bd12388cdb358fd8d318fcdee84f13d6b77eee81e8066b2e209a5ccb37018352`.
