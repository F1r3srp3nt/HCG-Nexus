# HCG Nexus Command Center (0.6.0)

HCG Nexus 0.6.0 is the command center for the HCG ecosystem on iPhone. It lists every HCG product by category
(search, favorites, expandable categories) and gives each one a profile. It also shows a connection dashboard,
notifications, a development roadmap and connected devices (through HCG System Tester), next to the existing
Package Trust Center, HCG Terminal and HCG Server integrations.

Code:

- `Sources/Core/HCGRegistry.{h,m}`: the registry loader.
- `Sources/Core/HCGCommandCenter.{h,m}`: connection status, roadmap, gaps and the LifeOS export.
- `Sources/Core/HCGDeviceInventory.{h,m}`: HCG System Tester inventory.
- `Sources/Core/HCGPublicFeeds.{h,m}`: the News and identity parsers.
- Screens in `Sources/Panel/HCGCommandCenterViewController.m`, `HCGProductProfileViewController.m`,
  `HCGRoadmapViewController.m` and `HCGDeviceClassesViewController.m`.
- Host tests in `Tests/Host/CommandCenterTests.m`.

## Rules

1. **Evidence only.** A product is *Connected* only after a two-way exchange succeeded recently (15 minutes), or when
   HCG Device Link reports a signed sync. Two-way exchanges are reads of a registry endpoint, HCG Halo's
   HaloNexusControl answer and Package Trust Center's read of HCG Repo. A URL, URL scheme or bundle identifier that
   exists never counts, and neither does opening an app, a screen or a website. *Installed* is shown as installed,
   never as connected.
2. **Nothing at startup.** Opening Nexus or the Command Center reads stored evidence and the existing read-only HIP
   scan. Every network read is a tap on *Check now*, and nothing retries by itself. No instrument, scan or connection
   starts on its own. Heavy work stays off SpringBoard's main thread: the HIP scan runs on a background queue, and the
   reads are small, size-limited and asynchronous.
3. **No invented links, endpoints, client IDs or permission keys.** Every link and endpoint in the registry is copied
   from the central HCG registry or the product's repository, with its source and date. All of them are `https` on
   `hakmicapitalgroup.com` (or a subdomain) without parameters, and every endpoint is anonymous and read-only.
   Products without verified links show no link.
4. **Registration is not authorization.** Being in the registry grants nothing. Private entries need their central
   entitlement (`product_id/feature_key`). Nexus has no HCG account (no client is issued), so private entries stay
   hidden.
5. **Every product keeps its own authority.** HCG System Tester stays the hardware authority, HCG Connect the identity
   authority, HCG Server the build and hosting authority, and each security product its own authorization boundary.
   Nexus starts no transformation, build, trade, payment, refund, advertising campaign, security instrument, vehicle
   or robot control, or firmware change. It introduces no grant authority of its own.

## Registry: `hcg.nexus.registry/1`

The registry is a data file, `Resources/Registry/hcg-ecosystem-registry.json`, not code.
`scripts/embed_registry.py` embeds it in the build (`Sources/Core/HCGRegistryData.m`), and `scripts/check.sh` fails
when the two differ.

**Top level:**

- `schema`, `registryVersion`, `generatedAt`
- `categories` (13)
- `connectionMethods` (10)
- `products` (41)
- `deviceClasses` (10)

**Per product:**

| Field | Meaning |
|---|---|
| `id` | Nexus registry ID (lower-case, `.`/`-`); for products with a HIP adapter `adapter: "hip:<HIP ID>"` |
| `officialName`, `aliases`, `nameVerified` | the registered name (central registry), or `nameVerified: false` when no official name exists |
| `category`, `description`, `kind` | `hub app tweak service website identity repository feature planned` (local app, remote service, website, planned …) |
| `central` | `productId`, `registration` (`registered proposed not-registered edition surface component feature`), `name`, `note` |
| `platforms`, `developmentStatus`, `lifecycle` | `lifecycle`: `active`, `suspended` (shown, nothing offered), `retired` |
| `visibility`, `entitlement` | `listed`, or private with `{product, feature}` |
| `distribution` | `channel`, `repoPackage` |
| `links.website` | only verified HCG websites |
| `endpoints` | `{id, url, auth: "none", access: "read", detail, verified}` |
| `contract` | `id`, `status` (`available planned none`), `detail` |
| `connectionMethods` | `{method, state: implemented/planned/unavailable, detail}` |
| `capabilities` | for products without a HIP adapter (HIP products use their resolved HIP capabilities) |
| `requirements` | development requirements `{id, title, detail, kind, blocking}` → gaps |
| `validations` | historical device validations (never imported) |
| `lastVerified`, `verifiedFrom` | when, and from what source, the entry was checked |

The **installed version** and **latest approved version** are runtime facts, not registry data. They come from dpkg
and from the HCG Repo lists your package manager downloaded (HIP).

**Updates.** Settings › HCG Nexus or the app, under Command Center › Registry › *Import registry update*, accepts a
higher-version `hcg.nexus.registry/1` file of at most 256 KB. An update:

- can add products, change descriptions and status, and suspend or retire products;
- can make a listed product private;
- can never add a link, endpoint, adapter, connection method or capability;
- never imports validation history.

Products it adds are text only. The central HCG registry publishes no public directory route yet:
`app_public_directory()` exists only as a database function, and `GET /api/public/pricing/v1/catalog` also lists
non-public products, so Nexus does not use it. That is recorded as the gap `nexus.central-app-access.public-directory`.

## Connection states

*Not on iPhone*, *Planned*, *Suspended*, *Retired*, *Not configured*, *Unable to check* (sandboxed app), *Not installed*,
*Installed*, *Ready* (Nexus can read it on request), *Connected*, *Disconnected* (connected before; stale or the last
read failed), *Connection failed*, *Built in*, *Website*.

The **connection ledger** (`connectionLedger`, at most 200 entries) records each read:

- product, method, outcome and time;
- a short sentence, never a URL, parameters, account or secret.

The profile shows the last successful communication and the last attempt.

## Roadmap

The roadmap has 14 states, derived from evidence in this order:

1. Lifecycle: retired → *Unsupported*; suspended → *Blocked*.
2. Connection: *Connected*, *Disconnected*, *Connection attempted*.
3. With an adapter:
   - *Validated*, when there is a historical device validation;
   - *Partially integrated*, when it is installed and some capabilities work while others are planned;
   - *Blocked*, when access is missing;
   - *Configuration required*, for a missing client, registration or signing;
   - *Ready to connect*;
   - otherwise *Adapter implemented*.
4. Without an adapter:
   - *Research required*;
   - *Contract available*, when a contract exists but is not reachable from iPhone;
   - *Adapter development required*;
   - otherwise *Registered*.

Each state carries its evidence sentence. The history (`roadmap`, at most 12 changes per product) grows only when the
derived state changes. Historical validations are shown in their own section and never change the current connection
status.

**Development gaps** are the registry's `requirements`, plus a computed "register centrally" gap for products with no
central row. Each gap has the stable ID `nexus.<product>.<requirement>`.

**Export to HCG LifeOS** (standalone app and Settings) writes a `lifeos.v1` import request
(hakmicapitalgroup `src/lib/lifeos/contract.ts`):

- one project, `nexus.ecosystem`, and one task per gap;
- `expected_revision: 0`, status `Stuck` for blocking gaps and `Later` otherwise, `source: {app: "hcg-nexus", …}`.

LifeOS's API accepts only its own Mac clients, so you preview and import the file in LifeOS.

**Duplicate protection:**

- stable IDs;
- no repeated ID in one file;
- a stored map of exported IDs and fingerprints, so an exported gap is never exported again, and a changed one is
  listed as "update it in LifeOS" instead of being re-added.

A gap is marked exported only after the share sheet reports that the file was saved. No XP field is written, and
LifeOS forces imported XP to 0.

## Connected devices: HCG System Tester

HCG System Tester (macOS) is the hardware communication authority. Nexus reads its exported inventory,
`hcg.systemtester.inventory/1`:

- `{schema, generatedAt, installationID, appVersion, devices[{key, name, category, status, connection,
  intelligenceState?, model?, osVersion?, provenance}]}`;
- System Tester redacts names before export;
- Nexus keeps only the last four characters of the installation ID.

Synthetic devices are labelled *SYNTHETIC* and never count as evidence.

The 10 device classes are:

- computers
- phones and tablets
- consoles (PS5)
- smart TVs (Samsung)
- vehicles (Audi R8)
- agricultural machinery (tractors)
- robots
- industrial machinery
- IoT and smart home
- microcontrollers

Each class shows:

- its devices from the inventory, with System Tester's own status;
- the System Tester adapters that exist today;
- what is missing;
- how to connect;
- a roadmap state;
- the safety rule.

Compatibility history is internal to System Tester (`connectivity.json`) and is not exported yet (gap
`nexus.system-tester.history-export`). Nexus never talks to a device and duplicates no device protocol.

## Product contracts (verified 26 Nov 2026)

| Area | What Nexus does | Contract / evidence | Not done (and why) |
|---|---|---|---|
| HCG Terminal / Unleashed | unchanged HIP integration (routes, declaration, versions) | `TerminalDeepLink` | — |
| HCG Server | unchanged: Connected Devices (HCG Device Link) in the standalone app; service health on the dashboard | `hcg.devicelink/1` | Device Link client 1.2.0 not adopted (1.1.0 vendored) |
| HCG Build Host | profile with its real state: contract exists, unreachable from iPhone | `hcg.buildhost/1` (loopback, bearer, admin approval) | needs a read-only Device Link route; no structured compiler diagnostics exist; Nexus never approves, submits or cancels |
| HCG Executable Maker Unleashed | profile: research required | private repository; no transformation contract found | proposed fields below; Nexus never runs transformations or generated code |
| Security (Sentinel, Vanguard, Offensive Frontier) | Sentinel: HIP links. Package authenticity, repository integrity and device compatibility: Package Trust Center | `hcgsentinel://open/<section>`, `hcg.repo.trust/1` | no findings, incident or assessment status is published by any of them; nothing is activated |
| HCG Trading, Trading Lab, Payments | Trading Lab website; HCG Trading and Payments research required | `hcg.trading.lab` registered; HCG Trading's domain appears in no HCG repository | no public trading or payment API; Nexus never trades, pays or refunds and holds no financial data |
| HCG News, ADS | News: *Check now* reads the latest published (approved) articles from `news.v1` | `https://beta.hakmicapitalgroup.com/api/public/news/v1/articles` (anonymous) | the live feed served an older format at its last documented check; ADS has no registry row or contract, and no campaign is ever activated |
| HCG Connect, ERP, App Access | *Check now* reads the public identity discovery (issuer, PKCE, scopes, revocation endpoint) | `/api/public/lifeos/v1/discovery` | sign-in, permissions, entitlements, device bindings and revocation need a registered `hcg.nexus` product and an issued client; none exists, and Nexus never reuses another product's client or simulates sign-in |
| HCG LifeOS | gap export file | `lifeos.v1` | the API refuses other clients |
| HCG AI | profile, website | `hcg-ai` registered | no gateway contract is published |

**Proposed for HCG Executable Maker Unleashed** (Nexus has no reader until the product publishes a contract).
`hcg.executable-maker-unleashed.transformation/1` would hold:

- job ID and status
- source and target platforms
- analysis status
- compatibility findings `{severity, title, detail}`
- build progress (0–100 and the current step)
- artifacts `{name, size, sha256}`
- a Transformation Passport (signed provenance)
- validation evidence `{device, date, result}`

It would be read-only and file or Device Link based, with no execution route.

**Local development vs HCG Connect.** A local-development pairing with HCG Server is labelled *LOCAL DEVELOPMENT —
not an HCG account* wherever it appears. It never counts as HCG Connect authorization, and no founder bypass exists.

## Editions

| | Jailbreak package (HCG Repo) | Standalone app (Xcode / TestFlight) |
|---|---|---|
| Registry, categories, search, favorites, profiles, roadmap | yes | yes |
| Installed products and versions | yes (dpkg, LaunchServices, read-only) | *Unable to check* (iOS sandbox) |
| Tweak status and settings (Halo, Vortex, Portal, Animation Center) | yes | no |
| HCG Halo border switch (HaloNexusControl) | yes | no |
| Opening products | bundle ID launch, Settings, package manager links | `canOpenURL` links only |
| HCG Server (Device Link) | no | yes |
| Check now (News, identity discovery), Package Trust Center reads | yes | yes |
| Import (System Tester inventory, registry update), LifeOS export | Settings › HCG Nexus | yes |

Both editions share one registry and one connection model. The jailbreak-only capabilities come from the jailbreak
environment (reading dpkg and other apps' `Info.plist`), never from bypassing iOS security in the standalone app.

## Not done (truthfully)

- No phone test of 0.6.0 yet: `DEVICE-CHECKLIST.md` rows 38–47 are pending.
- No live read was possible from the build session (its proxy refuses HCG hosts). The News and identity parsers are
  tested against fixtures built from the documented contracts; the first real *Check now* on a phone is the first live
  evidence.
- No official per-product icons exist. Products use generic system symbols; only HCG Nexus uses official HCG artwork
  (`Resources/Branding`).
