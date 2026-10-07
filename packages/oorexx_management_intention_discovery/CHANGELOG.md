# Changelog

## v0.1-dev7

- Rebased transient Network Transport specialist to Network Transport Intentions v0.1-dev2.
- Uses current Socket Provider v0.1-dev8 objects, including NORM and explicit multicast address/capability state.
- Uses current XTP v0.1-dev11 route objects; XTP path selection/multipath remains outside Management.
- Related-surface exploration now qualifies independent network path evidence and Spiral 1 COTS-interface witnesses without adding protocol knowledge to Management.
- Repeated exploration proves changed path evidence is refreshed and stale evidence is not retained.
- No cloud CLI, SSH, socket acquisition, network probe, route selection or mutation authority is added to Management.

# Changelog

## v0.1-dev6

- Integrates Network Transport Intentions v0.1-dev1 through dev5's transient related-surface advertisement seam.
- Uses the actual Socket Provider v0.1-dev2 address/family/capability objects and preserves XTP v0.1-dev6 route objects.
- Adds domain-owned network transport graph relationships without adding transport vocabulary to Management.
- Qualification proves a related logical service can advertise Network Transport Intentions and that a changed Socket Provider mapping is observed on the next identical exploration.
- Network Transport Intentions do not acquire sockets, probe networks, shell through XTP administration, select routes, or mutate route state.

## v0.1-dev5

See prior package for related-object transient intention-surface advertisement.
