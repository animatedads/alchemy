# Changelog

## 0.3
- Add the MVS 3.8J/TK5 backend validation stream and ED209ZZ clean-room evidence.
- Record the backend chain: schedule -> path -> rules -> fare -> PNR -> ticket/coupon -> boarding -> baggage -> cargo -> FLCTL.
- Record the ED209ZZ 3270 operating rule: one planned session at a time; the blank post-login TSO screen is a ready command environment, not a hang.
- Keep browser/Wire UI/Grok outside airline business authority.
- Preserve `flylo_v0.4.11.zip` as the durable ooRexx application baseline; MVS backend qualification is a separate line.

## 0.2
- Document FlyLo v0.4.11 baseline, authority map, UI regression lessons and continuation rules; explicitly defer generic row/list mechanics to shared Wire UI.
- Initial sphere scaffold.
