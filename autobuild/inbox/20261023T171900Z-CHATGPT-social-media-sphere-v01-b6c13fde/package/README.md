# ooRexx Social Media Gopher Sphere v0.1

Independent Gopher sphere `social-media`, complementing the existing `brand-interaction-stack` sphere. Exact source baseline `oorexx_social_media_v0.1-dev6.zip`, SHA-256 `f86ff802725ea83e856f8df10863bff8fcf7adcecf80240bc490696965ebfcda`.

The social media library covers communication surfaces across WhatsApp/email groups, Facebook/X, Reddit, Discord, Steam, YouTube creator comments, marketplace/eBay/Amazon seller interactions and local-business reviews. It is not a list of live installed adapters.

## Load

```sh
gopher sphere load social-media --override social_media_gopher_sphere_v0.1.zip
gopher --profile social-media context social-media
gopher --profile social-media open ops.social.start
gopher --profile social-media lookup topic=outbox --sphere social-media --corpus social.lessons
```

This is documentation continuity only, no authentication, authorization, spend, delivery or brand-effect authority. No live provider is implemented in dev6.

The development package's public lower-level publication service can bypass the strict facade if exposed. This is an explicit P0 production blocker, not hidden by documentation.

Static sphere assertions may PASS; LLM Gopher VALID/CLEAN and ooRexx runtime validation are not claimed.
