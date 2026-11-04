/* Rasen Falcon operational architecture: gate catalog, not invented evidence.
 * This module does not qualify any running service or select an instance.
 */
::requires 'ArchitectureServiceReadiness.cls'
::class ArchitectureRasenFalconBaseline public
::method build class
  use strict arg projectId
  p = .ArchitectureServiceReadiness~new(projectId)
  /* Public site: no blanket LDAP dependency on an anonymous visitor. */
  p~requireGate('public_website', 'public.site-source', -
    'Exact approved website source, content generation and digest', 'WEBSITE_PUBLISHER')
  p~requireGate('public_website', 'public.owned-https', -
    'Own HTTPS server route, policy-approved TLS certificate and CNAME routing', 'HTTPS_SERVER')
  p~requireGate('public_website', 'public.live-probe', -
    'Fresh deployed route and content probe, not a source test', 'DEPLOYMENT')
  /* Private operator surfaces have stronger service and identity boundaries. */
  p~requireGate('private_office', 'private.https-auth', -
    'Owned private HTTPS and Wire/WSS authenticated service route', 'HTTPS_SERVER')
  p~requireGate('private_office', 'private.ldap-active', -
    'Active attributed LDAP identity and explicit HTTPS_LOGIN permission', 'LDAP_IDENTITY')
  p~requireGate('private_office', 'private.live-probe', -
    'Fresh independent private HTTPS/WSS and identity-enforced live probe', 'DEPLOYMENT')
  /* SMTP and IMAP remain separate protocols and rights; no Bind=>SEND shortcut. */
  p~requireGate('mail', 'mail.smtp', -
    'Owned SMTP delivery service and policy-safe relay qualification', 'SMTP_SERVICE')
  p~requireGate('mail', 'mail.imap', -
    'Owned IMAP read/retention service and mailbox truth qualification', 'IMAP_SERVICE')
  p~requireGate('mail', 'mail.ldap-rights', -
    'Active LDAP principal plus explicit MAIL_READ and EMAIL_SEND rights', 'LDAP_IDENTITY')
  p~requireGate('mail', 'mail.own-tls', -
    'Own TLS server trust and secrets reference handling', 'MAIL_SECURITY')
  p~requireGate('mail', 'mail.live-probe', -
    'Independent SMTP/IMAP live end-to-end probe including denial paths', 'DEPLOYMENT')
  /* MU-to-MI admission cannot be inferred from generic IP reachability. */
  p~requireGate('internode', 'internode.xtp-route', -
    'Exact MI to own MU Layer 2 route / EtherType 0x817D evidence', 'XTP')
  p~requireGate('internode', 'internode.xtp-protection', -
    'Per-service authenticated session protection, key identity and fresh epoch', 'XTP')
  p~requireGate('internode', 'internode.named-service', -
    'Named service registration, selected carrier and end-to-end MU/MI probe', 'XTP')
  p~requireGate('internode', 'internode.deployment', -
    'Qualified node target and live deployment verification', 'DEPLOYMENT')
  return p
