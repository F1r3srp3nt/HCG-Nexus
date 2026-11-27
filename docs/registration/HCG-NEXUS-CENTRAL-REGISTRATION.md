# Registering HCG Nexus in the central product registry (prepared, not applied)

Prepared 27 Nov 2026 for the owner. **Nothing here has been applied:** the central registry is production data on the
main HCG platform, and only the owner registers products (ERP › App Access, owner role). No client ID and no feature
key is invented here.

## 1. Check first (no duplicate)

The live central catalogue (`GET https://beta.hakmicapitalgroup.com/api/public/pricing/v1/catalog`, 27 Nov 2026, 31
products) has **no `hcg.nexus`**. The platform's own documents use `hcg.nexus` "HCG Nexus" (planned) in the unapplied
proposal `docs/hcg-server/registry-review.sql`, and HCG Store already lists HCG Nexus as `hcg-nexus` (store slug, not a
central ID). Use the existing proposal's ID so all documents agree.

## 2. Product row (`app_applications`, ERP › App Access › Add application)

| Column | Value | Why |
|---|---|---|
| `product_id` | `hcg.nexus` | matches `^[a-z0-9][a-z0-9._-]{2,80}$` and the existing proposal |
| `name` | `HCG Nexus` | official full name |
| `description` | `The HCG ecosystem command center on iPhone: discovers, explains and opens HCG products, and connects only where a real integration exists.` | |
| `category` | `Software Distribution` | Nexus's own category set |
| `app_type` | `ios` | jailbreak package and iOS app |
| `platforms` | `{ios}` | |
| `release_status` | `testflight` | Candidate betas only; nothing on Stable |
| `lifecycle_status` | `beta` | |
| `public_listing` | owner's choice (`true` makes it appear in the public directory) | |
| `domains`, `launch_url` | none | Nexus has no website; the Store page is the Store's |
| `required_dependencies` | `{hcg.connect}` | sign-in, once a client exists |
| `integration_status` | `not_configured` | no client yet |

**Features: none yet.** Proposed for the owner to decide (not created by Nexus): `nexus.ecosystem.read` and
`nexus.devices.read`. Nexus asks other products only for read keys.

## 3. Then the native client

Follow docs/HCG-CONNECT-REGISTRATION.md § 0.7.0:

- client key `hcg-nexus-ios`, platform `ios`, environment `development`;
- the exact callback `com.hakmicapitalgroup.hcgnexus.app://auth/callback`;
- the issued client UUID goes into `App/Info.plist` `HCGConnectClientID`.

## 4. What changes in Nexus afterwards

- **Central registration:** HCG Nexus's own *Integration progress* shows it as done after the next *Update from
  central registry*.
- **Authentication:** stays pending until the client exists and a sign-in succeeds on a device.

Registration alone grants nothing and does not make anything connected.
