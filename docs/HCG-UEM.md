# HCG UEM integration (planned; proposed contract)

HCG UEM (Unified Endpoint Management) is a new HCG infrastructure project. As of 27 Nov 2026 it has no repository,
registry row or published interface that Nexus can reach. **Nothing in Nexus depends on it.** HCG Nexus lists it as a
*planned* product. The code below is prepared and tested, and nothing calls it with live data.

## HCG UEM as it exists (coordination, 27 Nov 2026)

Source: F1r3srp3nt/HCG-UEM, branch `claude/hcg-uem-infrastructure-ynngaz` @ `14d8ad7` (main holds only a README).

- **The service:** Go, `0.1.0-dev`, plus a macOS client with Secure Enclave keys. No iOS client.
- **Not deployed.** Production use is blocked by the founder decisions F1–F4. The proposed URL is
  `https://uem.hakmicapitalgroup.com`.
- **Device status:** `POST /v1/devices/self/status`. It needs an HCG Connect bearer token from a *trusted client*
  (the production list is empty) plus a device proof for `uem.device.status`. The answer is
  `DeviceStatus{summary, credentials, history, posture, classificationUnmet}`. The caller's own devices are at
  `GET /v1/me/devices`. The admin view (`uem.admin.devices.read`) is not for Nexus.
- **Classifications are governed data:**
  - `Catalog{revision, classifications[{key, tier, name, …, allowJailbroken, …}]}`, readable through admin
    governance only;
  - the default keys are `sovereign, administrative, development, managed, personal, unregistered`;
  - the tier number is display order only and never implies anything.
- **Jailbroken iOS is development or research only.** A jailbreak flag is never cleared by a later self-report. This
  matches Nexus's rule that a jailbroken device inherits no administrative privilege.
- **The macOS client already shows *HCG Nexus: not wired yet*.**

**Nexus's reader for the real shape:** `+[HCGUEM rowsFromUEMSelfStatus:catalog:error:]`, tested. It never connects.
Its rules:

- the device ID must match HCG UEM's format, or nothing else is shown;
- a lifecycle state other than `active` or `enrolled` (for example `quarantined`, `suspended`, `revoked`) puts the
  classification out of effect;
- classification names come only from HCG UEM's catalogue; without it, only the key is shown;
- Nexus never authorizes anything.

The earlier proposal below is kept, with its tested fail-closed parser, as history. Where HCG UEM differs, HCG UEM's
contract wins:

- `deviceId` instead of `hcgDeviceId`;
- `classification` key and catalogue instead of `tier` and policy;
- 11 lifecycle `state` values instead of `enrollment` and `lifecycle`;
- `credentials[]` statuses `pending | active | retired | revoked | expired`;
- `compliance` values `compliant | noncompliant | stale | unknown`;
- `connectivity` is added;
- no `inventory`;
- permissions appear only in the admin view.

**What Nexus needs from HCG UEM** (none of it exists yet):

1. A versioned schema ID on the self-status answer (for example under `hcg.uem.*`).
2. A read-only way for a non-admin client to read the trust catalogue's public fields (key, name, revision).
3. Nexus's future HCG Connect client on UEM's trusted-client list, decided by the founder, and an iOS enrollment
   path. Until then Nexus shows HCG UEM as *planned*, and nothing in Nexus waits for it.

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
