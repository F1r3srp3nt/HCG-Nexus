# HCG UEM integration (planned; proposed contract)

HCG UEM (Unified Endpoint Management) is a new HCG infrastructure project. As of 27 Nov 2026 it has no repository,
registry row or published interface that Nexus can reach. **Nothing in Nexus depends on it.** HCG Nexus lists it as a
*planned* product. The code below is prepared and tested, and nothing calls it with live data.

## Proposed contract `hcg.uem.device-status/1` (for the HCG UEM team)

Delivered by HCG UEM over an authenticated channel: an HCG Connect bearer token, or a signed HCG Device Link
exchange. Never from a file a user picks.

```json
{
  "schema": "hcg.uem.device-status/1",
  "issuedAt": "2026-12-01T10:00:00Z",
  "policy": { "id": "<HCG UEM policy id>", "version": 3,
              "tiers": [ { "level": 5, "key": "<key>", "name": "<name from HCG UEM policy>" } ] },
  "device": {
    "hcgDeviceId": "<HCG Device ID>",
    "enrollment": "enrolled | pending | not-enrolled",
    "identityVerified": true,
    "tier": 3,
    "credential": "valid | expiring | expired | revoked | none",
    "posture": { "state": "compliant | at-risk | non-compliant | unknown", "findings": [] },
    "permissions": [ "<product_id>/<feature_key>" ],
    "lifecycle": "active | suspended | revoked | retired",
    "jailbroken": true
  },
  "inventory": [ ],
  "history": [ { "at": "…", "event": "…" } ]
}
```

**Tiers come from HCG UEM's policy in each document.** The initially proposed tiers (5 Sovereign, 4 Administrative,
3 Development, 2 Managed, 1 Personal, 0 Unregistered) are HCG UEM's to define. Nexus contains none of them: a level the
policy does not name is shown as *Not classified by HCG UEM policy*.

## Rules (enforced in `Sources/Core/HCGUEM.m`, tested in `Tests/Host/CommandCenterTests.m`)

- Nexus never assigns a tier, grants trust or authorizes a privileged operation; `HCGUEMNexusMayAuthorize()` is
  always NO.
- A jailbroken device gains nothing: the jailbreak is shown, and Nexus offers no administrative action.
- Suspended, revoked or retired devices show that state, and their tier and permissions are not in effect.
- Device-specific permissions are listed as HCG UEM states them; access decisions stay with HCG UEM and HCG Connect.

## Still needed (HCG Nexus's roadmap entry `uem`)

1. A central registry row for HCG UEM.
2. HCG UEM's published contract (this proposal or its own).
3. An authenticated channel: HCG Connect client, or HCG Device Link.
4. Physical testing and a security review.
