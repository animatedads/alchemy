# NOC and Office — private HTTPS boundary

Approved direction, **not a claim of deployment**.

NOC and Office run as **separate native ooRexx HTTPS servers**, separately supervised by systemd and isolated using the RexxOS execution/service model. They have distinct Unix service identities, processes, listeners, credentials, leaf certificates and TLS state. Public RasenFalcon does not share their default listener or security authority.

Each server presents its **own** leaf certificate signed by the owner-controlled **private CA**. The private root **public trust certificate** is provisioned only to designated browsers/devices; server private keys are never installed on devices. Each authorized device must also carry an individual **client certificate and private key** recognized by the service. Merely installing the private CA root in a browser does not prevent unprovisioned clients from connecting: **mandatory server-verified TLS client authentication (mTLS)** is the critical additional control. Certificate mapping is followed by LDAP + Access Permissions. Revoked/untrusted/expired/missing/wrong-purpose client certificates are refused before any application request; missing issuance, invalid rotation, missing CRL/status evidence and bad TLS configuration all fail closed.

NOC's certificate must cover `noc.rasenfalcon.com` although DNS CNAME resolves via `london1.rasenfalcon.com`; Office's certificate must cover `office.rasenfalcon.com`. Missing/unknown SNI is rejected for either private service; SNI/Host disagreement denied. Neither has an HTTP/80, public CA, anonymous, password-only, shared-default-vhost or unauthenticated proxy fallback. No server cert or root private key is included in any source bundle.

Separate trust boundary: **public** `rasenfalcon.com` (and explicitly adopted `www` if approved) remains a public website with its own appropriate public TLS certificate. No private-office or private-NOC client certificate must be demanded for general public marketing pages; the public listener cannot route to private APIs. Public server certificates are not a source of trust for private endpoints.

**Qualify:** real TLS handshakes for authorized client, no certificate, untrusted client chain, wrong EKU, expired, revoked, wrong SAN/Host/SNI, restart/rotation, private issuer unavailable and replay/stale generation. Failures cannot fall back. None of these native network tests have been run by this handoff.

**Scheduling:** systemd supervises services. The existing BashQueues cron bridge uses the **systemd per-minute timer only to wake the ticker**, which submits jobs; BashQueues workers run application tasks. No system crond or application crontab dependency; schedule backups, key-renewal workflows, health and audits through BashQueues with explicit classes/policy/anti-overlap. An offline private issuer must never trigger ACME/public issuance.
