# HCG Store: centrally authorized read-only access for HCG Nexus (proposal)

**Status:** proposal for HCG Store, HCG Store Manager and the owner, 27 Nov 2026. Nothing here exists as an
authorization today. Nexus never uploads, approves, publishes, disables or restores releases.

**Sources:**

- F1r3srp3nt/store main @ `2fb1e3c`: Control Center, release lifecycle (`server/src/release-lifecycle.ts`),
  `docs/ADMINISTRATION.md`;
- HCG-Store-Manager @ `e6a3e2a` (`Sources/StoreManagerKit/StoreAPI.swift`);
- Distribution Studio, an HCG Executable Maker feature whose Store API is on the unmerged store branch
  `claude/distribution-studio-api`.

## Working today (public, anonymous, read-only)

`GET https://store.hakmicapitalgroup.com/api/public/v1/release-resolution/<product>` (`hcg.store.release-resolution/1`):
product status, current published release, download options and their access, including open free testing windows.
HCG Nexus reads it in HCG Store › Check now and HCG ONE: UNLEASHED › Check now. It contains no download URLs and
grants nothing.

## Needed: authenticated read-only access

| Nexus shows | Store route (exists, bearer-authenticated) | Fields |
|---|---|---|
| Release drafts, approval status | `GET /api/v1/publishing/manager` | `releases[]`: `status`, `stage`, `approvedEligibility`, `lifecycle.label` |
| Upload progress, artifact verification | `GET /api/v1/publishing/releases/{id}` | per file: `receivedBytes`, `sizeBytes`, `sha256`, `declaredSha256`, `status` (`verified`), validation |
| Current, superseded and disabled versions | same release views | lifecycle `status` (`… published · superseded · withdrawn`), `availability` (`available · disabled · archived · revoked`), `targets[].current` |
| Release Passports | release file passport (submitted by Store Manager) | Nexus's Package Trust Center already reads HCG Repo passports |
| Temporary testing offers | `GET /api/v1/publishing/offers/windows` | `windows[{productId, releaseId, startsAt, endsAt, state, terminatedAt}]` |
| Store availability | `GET /api/v1/health` (public) | already read |

**Why a new permission is needed.** On store main, reading the publishing API requires holding `store.publish`,
`store.release.approve` or `store.release.publish` (`mayReview`). All three grant write power. Nexus must never hold
them just to read.

**The request:**

- HCG Store defines one read-only permission on `hcg.store`. Its name is HCG Store's choice; Nexus proposes none.
- `mayReview` accepts that permission for `GET` routes only.
- Every write route keeps refusing it.

## Authorization chain (central, nothing local)

1. The owner registers `hcg.nexus` and issues its HCG Connect client (docs/registration/).
2. HCG Store adds that client ID to `HCG_STORE_PUBLISHING_CLIENT_IDS`.
3. The owner grants the read-only permission to the people who should see release status in Nexus. HCG Store checks it
   through HCG Connect's `/check` on every request.
4. Nexus calls only the `GET` routes above, shows the answer read-only, and records each exchange as authenticated
   evidence.
5. Device-aware rules (HCG UEM) come later. HCG Store's `/me` already reports "device-aware authorisation (HCG UEM)
   is not active".

Until steps 1–3 are done, HCG Store Manager's authenticated capabilities stay *planned* in Nexus.
