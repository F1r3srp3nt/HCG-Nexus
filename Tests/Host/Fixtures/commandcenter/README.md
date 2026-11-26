# Command Center fixtures

Constructed for the host tests (not captured from live services; this session cannot reach HCG hosts):

* `inventory.json`: the shape HCG System Tester 0.3.0 writes for `hcg.systemtester.inventory/1` (JSONEncoder, sorted
  keys, ISO 8601 dates; `DeviceInventorySnapshot` in HCG-System-Tester `Sources/HCGCore/Reports/DeviceReport.swift`),
  with one synthetic device and one record with values this version does not know.
* `news.json`: a `news.v1` list with the documented fields (hakmicapitalgroup `docs/news-api/native-app-handoff.md`),
  including the documented test story and a demo story with a non-HCG link.
* `discovery.json`: the identity discovery shape (`src/routes/api/public/lifeos/v1/discovery.ts`) with a dummy client ID
  that must never be shown.
