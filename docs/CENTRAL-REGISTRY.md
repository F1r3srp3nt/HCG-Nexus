# HCG Nexus 0.7.0: central registry and live ecosystem connections

Code:

- `Sources/Core/HCGCentralRegistry.{h,m}`: the central registry client.
- `Sources/Core/HCGCommandCenter.{h,m}`: evidence layers.
- `Sources/Core/HCGPublicFeeds.{h,m}`: News, identity and Store health.
- Command Center › Registry (`HCGRegistryInfoViewController`).
- Tests in `Tests/Host/CommandCenterTests.m`, which include live captures from 26 Nov 2026.

## Central registry (P0)

**Authority.** The main HCG platform's product registry (`app_applications`) is the authority for product identity:
the official name, the central product ID and the release status. The only anonymous projection of it available today
is the public catalogue:

`GET https://beta.hakmicapitalgroup.com/api/public/pricing/v1/catalog`

The live check on 26 Nov 2026 returned 200, `Cache-Control: public, max-age=30`, no ETag and no signature,
`api_version` "1" and 31 products.

**What Nexus does with it:**

- **Fetch:** only when you tap *Update from central registry*, never at startup. It is an ephemeral HTTPS GET to that
  fixed URL, with no cookies or credentials, no redirects, and at most 256 KB.
- **Validation:**
  - `api_version` must be "1";
  - at least 5 products with valid IDs;
  - the version is the SHA-256 of the identity fields (product ID, name, status, release status), so an unchanged
    catalogue keeps its version.
- **Apply:** only to products Nexus already lists, by central product ID. Name and release status come from the
  catalogue, and the product is marked *registered* (verified live).
  - It never adds a product, link, endpoint, adapter, capability or permission, and never changes visibility or
    entitlements: being in the registry grants nothing.
  - A product the built-in registry calls registered but the catalogue omits is reported (it may be retired or
    deprecated).
- **Cache and rollback:** the current and the previous valid snapshot are kept in Nexus's preferences. You can
  *Restore previous snapshot* or *Use built-in registry only*. A failed fetch keeps the last valid snapshot.
- **Offline:** the last valid snapshot, or the built-in registry, always works.

**Authority cannot be redefined by files.** An imported `hcg.nexus.registry/1` update:

- cannot change a product's official name, central ID or registration;
- cannot change a private product's entitlement;
- cannot add links, endpoints, adapters, connection methods or capabilities;
- cannot add validation history.

Products it adds are marked *not registered* with an unverified name. The central source URL is fixed in code.

**Permission filtering.** Nexus shows private registry entries only with their central entitlement
(`product/feature`). Without an HCG Connect client (none is issued), private entries stay hidden. The signed-in
`GET /api/public/app-catalog` is **not** a permission filter: it lists every non-archived product to any signed-in user.
Per-account access must come from `/access` and `/check` (docs/HCG-CONNECT-REGISTRATION.md).

**What the platform should add (proposal for the main-site team).** The public catalogue also lists products that are
not publicly listed. Its SQL function filters only on lifecycle, not on `public_listing`. That conflicts with "only
public metadata" (AGENTS.md:15). The proposal is `GET /api/public/ecosystem/v1/directory`, returning
`hcg.ecosystem.directory/1`, which:

- lists only `public_listing` products, with ID, name, category, release status and lifecycle;
- carries a monotonically increasing `version` and `issued_at`;
- carries a detached signature by a platform key, published at a fixed path and pinned in Nexus (like HCG Repo's key
  pinning);
- sends an ETag.

Nexus would accept a new directory only when the signature verifies and its version is not lower than the cached one.
Until then, Nexus treats HTTPS to the platform's own host as the transport authentication, and says so.

## Evidence layers (P1)

Each product profile shows seven separate layers (*Evidence*):

1. Registered product
2. Installed application
3. Available service
4. Authenticated connection
5. Verified capability
6. Current connection health
7. Historical validation

Each connection method now has an access class:

| Access class | Methods | What a success proves |
|---|---|---|
| `public` | HTTPS reads | The service is reachable (*Public service reachable*), never *Connected* |
| `local` | A product-owned interface on this iPhone, e.g. HCG Halo's HaloNexusControl | *Connected (local interface)*, not authenticated |
| `authenticated` | Signed HCG Device Link, HCG Connect bearer | *Connected* and *Authenticated connection* |
| `none` | Navigation | Proves nothing |

A successful public metadata request never establishes authenticated or administrative access. In the roadmap, a
public read completes a public-only integration (HCG News). Where authenticated access is part of the integration, it
is *Partially integrated* (HCG Connect: discovery reachable, no client).

## Live verification, 26 Nov 2026 (anonymous, read-only)

| Endpoint | Result |
|---|---|
| `beta…/api/public/news/v1/articles` | 200, `news.v1`, 13 articles |
| `beta…/api/public/lifeos/v1/discovery` | 200, PKCE S256, no revocation endpoint |
| `beta…/api/public/pricing/v1/catalog` | 200, 31 products (central registry) |
| `beta…/api/public/app-catalog`, `…/ecosystem/v1/me` | 401 without a token (as designed) |
| `store.hakmicapitalgroup.com/` and `/api/v1/health` | 200; health: `status ok`, `mode production`, HCG Connect configured, payments and protected downloads disabled |
| Store publishing manager | 404 `publishing_disabled` |
| Store release resolution (`hcg-one-unleashed`, `hcg-mail`) | 404 (route not deployed) |
| `beta…/trader-mission/simulator` | 200 |
| `trading.hakmicapitalgroup.com` | no answer (the network proxy got no response from the host) |

## Product coordination (what exists, what Nexus needs)

**HCG Store Manager** (Software Distribution, new entry).

- *HCG Store Manager* is documented as the native admin client of the Store publishing API (store `1e93880`
  `web-hcg-store/docs/PUBLISHING.md`). It has no app or registry row of its own.
- The read routes exist in code:
  - `publishing/manager`: drafts, pending approvals, published releases;
  - `publishing/releases/{id}`: upload status and artifact SHA-256 and validation;
  - `publishing/capabilities`, `publishing/whoami`.
- They are disabled in production (404) and need an HCG Connect bearer token whose client is on the Store's allow-list,
  plus `store.publish`, `store.release.approve` or `store.release.publish`. All three grant write power, and all are
  granted to nobody.
- Temporary testing offers ("free testing windows") are an operator command, not an API. Sync health has no API; only
  `auditIntact` and the public health exist.
- **Needed for Nexus:**
  - enable publishing in production;
  - a read-only key (`store.release.read`);
  - the Nexus client on the allow-list.
- Nexus will never upload, approve or publish.
- Today Nexus reads the public Store health (*Check now*).

**HCG Store v3 (update 27 Nov 2026).**

- **Publishing API:** now deployed. Without an HCG Connect token, `publishing/manager`, `publishing/capabilities` and
  `repo/releases` answer 401 `sign_in_required`.
- **Public release resolution:** now live (`hcg.store.release-resolution/1`, anonymous, CORS `*`, 60 s cache). HCG
  Nexus is listed as `testing` with no published Store release; HCG ONE: UNLEASHED as `in-development`, also with
  none.
- **What Nexus reads today**, through HCG Store › Check now (public, read-only):
  - Store availability (health);
  - current published versions and download access, including temporary free testing windows with their end date.
- **Still needing HCG Connect and a read-only Store permission:**
  - private release drafts;
  - upload progress;
  - release validation;
  - superseded and disabled versions;
  - Store-side Release Passports;
  - pending approvals.
- **Product catalogue:** the Store has no public product-catalogue route (`/api/public/v1/catalog` and
  `/api/public/v1/products` answer 404).

Nexus never uploads, approves, publishes or disables releases.

**HCG Trading.**

- `trading.hakmicapitalgroup.com` did not answer and appears in no registry. Nexus shows no link and invents no
  availability or market data.
- The registered simulators are **HCG Trading Lab** (`hcg.trading.lab`, web, live page) and **HCG ONE: UNLEASHED**
  (`hcg.one.unleashed`, native, new entry).
- Approved simulator releases will come from the Store's `hcg.store.release-resolution/1`
  (`GET /api/public/v1/release-resolution/hcg-one-unleashed`, anonymous). That route is implemented but not deployed.

**HCG System Tester (Universal Connectivity Center).**

- No exported, versioned device roadmap contract exists (main `3e03d8b`, all branches). The only exports are
  `hcg.systemtester.inventory/1` (unchanged; Nexus imports it) and a LifeOS quest file (`hcg.lifeos.backlog` v2).
- The roadmap, evidence, requirements, protocols and connection methods live in System Tester's internal
  `connectivity.json` (`ConnectivityState` schemaVersion 1) and its built-in profiles.
- **Proposed export** `hcg.systemtester.connectivity/1`, a file and later Device Link. It would carry:
  - `roadmapItems[{id, kind, title, state, reason, history}]`, using System Tester's own `RoadmapState` values;
  - `evidence[{at, kind, outcome, protocolID, summary, provenance, testsPassed, testsApplicable}]`, hardware
    provenance only;
  - `requirements[{id, kind, title, detail, priority, acceptanceCriteria}]`;
  - `protocols[{id, name, discovery, communication, validation}]`;
  - `methods[{id, title, requiredEquipment, steps, safety}]`;
  - `devices[]` (as in the inventory).
- Nexus would show connection instructions, required adapters, supported protocols, connected devices, compatibility
  evidence, missing requirements and the device roadmap from it. System Tester stays the hardware authority, and
  Nexus offers no control.

**HCG Executable Maker and Executable Maker Unleashed.**

- Maker has no network interface. Its machine-readable outputs are files:
  - `hcg.native-build-request` / `hcg.native-build-result` v1;
  - `hcg.build-diagnostics` v1;
  - `hcg.release-passport` v1, which Nexus's Package Trust Center already reads.
- An unmerged branch adds a desktop command contract, `hcg.executable-maker.integration/1`.
- Unleashed (private) publishes no transformation contract.
- Nexus will add read-only adapters (file import, then Device Link) when a versioned interface is published. It never
  runs builds, transformations or generated code.

**Security division (Sentinel, Vanguard, Offensive Frontier, Signal Contractor).**

- No versioned findings or status interface is published. HCG Sentinel imports `hcg.diagnostic-report/1` but publishes
  no status snapshot.
- Each product keeps its own authorization boundary. Nexus activates nothing and adds no grant authority.
- Needed: a read-only `status` and `findings` export per product (findings shaped like `hcg.diagnostic-report/1`:
  title, severity, confidence, basis, evidence, remediation).
