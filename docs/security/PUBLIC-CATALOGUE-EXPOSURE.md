# Public catalogue exposure: non-public products (sanitized report)

**Status:** reported to the owner, 27 Nov 2026. **Not changed by HCG Nexus:** the fix belongs to the main HCG
platform. Nexus does not modify the platform's production security configuration.

This public report names no product. The owner holds the full list privately. Each product here is identified by the
first 12 hex digits of SHA-256(product_id), so the platform team can match rows against `app_applications` without
the identifiers being republished.

## Affected endpoints

| Endpoint | Auth | Finding | Evidence |
|---|---|---|---|
| `GET https://beta.hakmicapitalgroup.com/api/public/pricing/v1/catalog` | none (CORS `*`, `Cache-Control: public, max-age=30`) | Returns **31** products; only **14** are in the platform's public directory. **17 non-public products** are exposed anonymously, with name, description, status, release status, platforms, dependencies and features. One internal product's response includes **23 feature definitions**. | Live, 27 Nov 2026 (below) |
| `GET https://beta.hakmicapitalgroup.com/api/public/app-catalog` | any signed-in HCG user | Returns every non-archived product to any authenticated user, whatever their entitlements (`app_safe_catalog()`, migration 0038). | Code review, hakmicapitalgroup `57d05ac` `src/routes/api/public/app-catalog.ts`; live 401 without a token |

**Cause (code):** `eco_public_pricing()` (migration `0019_pricing_publication.sql`, granted to `anon`) filters only on
`lifecycle_status NOT IN ('retired','deprecated')`. Unlike `app_public_directory()` (migration 0040), it does not
require `public_listing`. That conflicts with AGENTS.md ("only public metadata").

## Reproduction (anonymous, read-only)

```sh
curl -s https://beta.hakmicapitalgroup.com/api/public/pricing/v1/catalog | jq '.products | length'   # 31
curl -s https://beta.hakmicapitalgroup.com/products > products.html   # its embedded `directory` array = app_public_directory(): 14 rows
# products present in the catalogue but absent from the public directory: 17
```

| SHA-256(product_id)[:12] | status | release_status | features exposed |
|---|---|---|---|
| `c210417aa40f` | planned | planned | 0 |
| `b5eff9e3b983` | development | in_development | 0 |
| `4083df33a2ca` | planned | planned | 0 |
| `9837b3fbce5c` | planned | planned | 0 |
| `eaf24da5bd40` | planned | planned | 0 |
| `14d719222817` | planned | planned | 0 |
| `e91a377124a3` | planned | planned | 0 |
| `505692eb24ae` | internal | in_development | 0 |
| `d3ff069e1238` | planned | planned | 0 |
| `c8fb2446eb77` | planned | planned | 0 |
| `734513c5840f` | planned | planned | 0 |
| `0389d67b4497` | planned | planned | 0 |
| `4ab5a98825da` | development | planned | 0 |
| `9a03669f7860` | development | planned | 0 |
| `9ba58a905706` | internal | published | 23 |
| `e34987f6d53c` | active | published | 0 |
| `5799fb239cfc` | active | in_development | 0 |

Totals by (status, release_status): {'planned/planned': 10, 'development/in_development': 1, 'internal/in_development': 1, 'development/planned': 2, 'internal/published': 1, 'active/published': 1, 'active/in_development': 1}.

## Recommended fix (for the main-site team; needs the owner's approval)

1. Redefine `eco_public_pricing()` to also require `public_listing` and `release_status <> 'archived'`, keeping the
   response shape. Add a test that a non-listed product is absent.
2. Restrict `app_safe_catalog()` / `GET /api/public/app-catalog` to products the caller may see (listed, or entitled
   through `/access`), or document it as staff-only.
3. Optionally publish the signed directory proposed in docs/CENTRAL-REGISTRY.md.

## HCG Nexus's own behaviour

- Nexus uses the catalogue only to confirm the identity of products it already lists. It never adds a product from
  it, so non-public catalogue entries are never displayed (tested: `testCentralRegistry`).
- Private registry entries need their central entitlement; Nexus has no account, so they stay hidden.
- Nexus does not cache or show feature definitions, descriptions or dependencies from the catalogue: only product ID,
  name and status are parsed.
