# Command Center fixtures

Constructed for the host tests (not captured from live services; this session cannot reach HCG hosts):

* `inventory.json`: the shape HCG System Tester 0.3.0 writes for `hcg.systemtester.inventory/1` (JSONEncoder, sorted
  keys, ISO 8601 dates; `DeviceInventorySnapshot` in HCG-System-Tester `Sources/HCGCore/Reports/DeviceReport.swift`),
  with one synthetic device and one record with values this version does not know.
* `news.json`: a `news.v1` list with the documented fields (hakmicapitalgroup `docs/news-api/native-app-handoff.md`),
  including the documented test story and a demo story with a non-HCG link.
* `discovery.json`: the identity discovery shape (`src/routes/api/public/lifeos/v1/discovery.ts`) with a dummy client ID
  that must never be shown.

## Live captures (26 Nov 2026, anonymous GETs from the build session, no credentials)

* `live-news-2026-11-26.json`: `GET https://beta.hakmicapitalgroup.com/api/public/news/v1/articles?page=1&per_page=3`
  answered 200, `news.v1`, total 13.
* `live-discovery-2026-11-26.json`: `GET https://beta.hakmicapitalgroup.com/api/public/lifeos/v1/discovery` answered
  200. It contains LifeOS's public client IDs, which Nexus never shows (tested).
* `live-app-catalog-401-2026-11-26.json`: `GET https://beta.hakmicapitalgroup.com/api/public/app-catalog` without a
  token answered 401 `unauthorized`. The signed-in catalog needs an HCG Connect token.
* `live-central-catalog-2026-11-26.json`: derived from the central catalogue answer of 26 Nov 2026 (200, api_version "1"),
  reduced to the products HCG Nexus already lists publicly and to the identity fields Nexus reads (ID, name, status,
  release status). Nothing else from the answer is kept.
* `live-store-health-2026-11-26.json`: `GET https://store.hakmicapitalgroup.com/api/v1/health` answered 200 (mode production).
* `live-store-release-hcg-nexus-2026-11-27.json`: `GET https://store.hakmicapitalgroup.com/api/public/v1/release-resolution/hcg-nexus` answered 200 (`hcg.store.release-resolution/1`, no releases published).
