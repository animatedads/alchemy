# Authority boundary

- `alchemy.cloud-control/0.1 RESOURCE` owns cloud resource mutation syntax and provider/account selection.
- ooRexx Cloud Console is a UI/automation facade. It may PLAN, confirm and delegate; it is not provider authority.
- Provider-native read observations may be consumed independently and must retain provenance.
- XTP owns transport topology and peer-set meaning. Cloud Control may reconcile a supplied firewall source set but must not invent peer membership.
- Managed-node identity is separate from provider resource handles.
- Credentials are not authority and are never accepted as resource-spec fields.
