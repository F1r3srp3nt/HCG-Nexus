# `hcg.integration-qualification/1`: the HCG integration qualification standard (proposed for reuse)

HCG Nexus produces this record from evidence (`+[HCGCommandCenter qualificationRecordForItems:…]`, tested in
`Tests/Host/CommandCenterTests.m`). Any HCG product can produce or read the same record for its own integrations:
HCG System Tester, HCG Store Manager, HCG UEM, HCG LifeOS.

## Record

```json
{
  "schema": "hcg.integration-qualification/1",
  "subject": "hcg-nexus",
  "generatedAt": "2026-11-27 10:00 UTC",
  "registryVersion": 4,
  "products": [
    { "id": "news", "name": "HCG News", "centralProductId": "hcg.news",
      "checkpoints": [ { "key": "central-registration", "state": "done", "evidence": "hcg.news (verified live)" } ] }
  ]
}
```

`subject` is the product doing the integrating. Each product carries the nine checkpoints in this order.

## Checkpoints

| Key | `done` only when |
|---|---|
| `central-registration` | the product is in the central registry (verified from the registry itself) |
| `authentication` | an authenticated exchange succeeded (signed HCG Device Link, HCG Connect bearer). It is `not-needed` when the integration has no authenticated part |
| `api-contract` | a versioned contract is published by the product (`partial`: planned) |
| `adapter` | the integrating product has an adapter for that contract |
| `configuration` | no blocking configuration or registration step remains |
| `communication` | a two-way exchange succeeded recently (`partial`: succeeded before, not now) |
| `capability-validation` | every offered capability was verified on a device (`partial`: some were) |
| `physical-testing` | a recorded device result exists (device, OS, version, date). An owner's statement is recorded first |
| `security-review` | a recorded review exists (date, scope, outcome) |

**States:** `done`, `partial`, `pending`, `not-needed`. Every state carries its evidence sentence. Being registered
never makes a product connected. A public read never counts as authentication. Nothing is marked done without the
evidence in the table.

## Development gaps in HCG LifeOS (coordination)

The HCG LifeOS export (`lifeos.v1` import file, docs/COMMAND-CENTER.md) uses stable IDs and duplicate protection, and
claims no XP.

- **Proposed extension, not yet exported:** each `pending` checkpoint becomes one task with the stable ID
  `nexus.<product>.checkpoint.<key>`, status `Later` (or `Stuck` when blocked by another product), in the project
  `nexus.ecosystem`.
- **Completion:** a task is completed only from LifeOS's own workflow when the evidence exists. Nexus never sends a
  completion event and never awards XP; LifeOS forces imported XP to 0.
- **Still to agree with HCG LifeOS:** whether checkpoint tasks share the `nexus.ecosystem` project or get one per
  product, and how a `done` checkpoint is reported back (a new export marks it, or LifeOS asks the subject).
