# Teller Cash closure note

The supplied `oorexxapis(20260828-191958).zip` contains:

- `federationbank_teller_till_v0.2.zip`
- `federationbank_teller_cash_v0.1.zip`
- `federationbank_teller_cash_service_v0.1.zip`

The Teller Cash dependency declaration references `federationbank_teller_till_service_v0.1`. That package/service implementation is not present in the roll-up.

Therefore Teller Cash is not included in the accepted Staff Banking v0.3 aggregate. Do not replace the missing dependency with Teller Till v0.2 merely because the name is similar; an explicit migration or exact dependency delivery is required.
